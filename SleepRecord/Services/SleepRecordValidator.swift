import Foundation

/// Validates the time-ordering invariants of a sleep record before it can be saved.
///
/// Rules:
/// - bedInAt < bedOutAt   (bed window must be non-empty)
/// - bedInAt ≤ asleepAt   (you can't fall asleep before getting in bed)
/// - asleepAt ≤ awakeAt   (sleep onset must be at or before wake)
/// - awakeAt  ≤ bedOutAt  (you can't wake after leaving bed)
enum SleepRecordValidator {
    enum Issue: Equatable {
        case bedWindowInverted          // bedInAt >= bedOutAt
        case asleepBeforeBedIn          // asleepAt < bedInAt
        case awakeAfterBedOut           // awakeAt > bedOutAt
        case asleepAfterAwake           // asleepAt > awakeAt
        case wakeEventOutOfBounds       // wake event start or end outside [bedInAt, bedOutAt]
        case wakeEventOverlap           // two wake events have overlapping ranges
        case wakeEventInverted          // wake event endedAt <= startedAt
    }

    static func validate(
        bedInAt: Date,
        bedOutAt: Date,
        asleepAt: Date,
        awakeAt: Date
    ) -> Issue? {
        if bedInAt >= bedOutAt { return .bedWindowInverted }
        if asleepAt < bedInAt { return .asleepBeforeBedIn }
        if awakeAt > bedOutAt { return .awakeAfterBedOut }
        if asleepAt > awakeAt { return .asleepAfterAwake }
        return nil
    }

    /// Variant for the morning correction sheet: bed times are fixed (already
    /// recorded by tap), only sleep times are user-editable. bedOutAt may still be
    /// nil if the session is in progress; pass `.now` (or a sensible upper bound)
    /// in that case.
    static func validateSleepOnly(
        bedInAt: Date,
        bedOutAt: Date,
        asleepAt: Date,
        awakeAt: Date
    ) -> Issue? {
        if asleepAt < bedInAt { return .asleepBeforeBedIn }
        if awakeAt > bedOutAt { return .awakeAfterBedOut }
        if asleepAt > awakeAt { return .asleepAfterAwake }
        return nil
    }

    /// Validates a list of (startedAt, endedAt?) wake events against the bed
    /// window. Returns the first issue found, or nil if all events are OK.
    /// Open events (endedAt == nil) are accepted as long as startedAt is in bounds.
    static func validateWakeEvents(
        _ events: [(startedAt: Date, endedAt: Date?)],
        bedInAt: Date,
        bedOutAt: Date
    ) -> Issue? {
        let upper = bedOutAt
        for e in events {
            if e.startedAt < bedInAt || e.startedAt > upper {
                return .wakeEventOutOfBounds
            }
            if let end = e.endedAt {
                if end < bedInAt || end > upper {
                    return .wakeEventOutOfBounds
                }
                if end <= e.startedAt {
                    return .wakeEventInverted
                }
            }
        }
        let closed = events.compactMap { e -> (Date, Date)? in
            guard let end = e.endedAt, end > e.startedAt else { return nil }
            return (e.startedAt, end)
        }
        for i in 0..<closed.count {
            for j in (i + 1)..<closed.count {
                let a = closed[i], b = closed[j]
                if a.0 < b.1 && b.0 < a.1 { return .wakeEventOverlap }
            }
        }
        return nil
    }
}

extension SleepRecordValidator.Issue {
    /// Display message for the given issue, used in form error labels.
    /// Looks up the localized string at runtime; defaultValue is the Japanese
    /// development-language source.
    func message(bedInAt: Date? = nil, bedOutAt: Date? = nil) -> String {
        switch self {
        case .bedWindowInverted:
            return String(
                localized: "validator.bedWindowInverted",
                defaultValue: "「布団に入った」は「布団から出た」より前である必要があります"
            )
        case .asleepBeforeBedIn:
            if let d = bedInAt {
                let time = SleepRecordValidator.shortTime(d)
                return String(
                    localized: "validator.asleepBeforeBedIn.withTime",
                    defaultValue: "入眠時刻は入床時刻（\(time)）以降にしてください"
                )
            }
            return String(
                localized: "validator.asleepBeforeBedIn",
                defaultValue: "「眠った」は「布団に入った」以降である必要があります"
            )
        case .awakeAfterBedOut:
            if let d = bedOutAt {
                let time = SleepRecordValidator.shortTime(d)
                return String(
                    localized: "validator.awakeAfterBedOut.withTime",
                    defaultValue: "覚醒時刻は起床時刻（\(time)）以前にしてください"
                )
            }
            return String(
                localized: "validator.awakeAfterBedOut",
                defaultValue: "「目覚めた」は「布団から出た」以前である必要があります"
            )
        case .asleepAfterAwake:
            return String(
                localized: "validator.asleepAfterAwake",
                defaultValue: "「眠った」は「目覚めた」より前である必要があります"
            )
        case .wakeEventOutOfBounds:
            return String(
                localized: "validator.wakeEventOutOfBounds",
                defaultValue: "中途覚醒の時刻は入床〜起床の範囲内に収めてください"
            )
        case .wakeEventOverlap:
            return String(
                localized: "validator.wakeEventOverlap",
                defaultValue: "中途覚醒の時間が他のイベントと重なっています"
            )
        case .wakeEventInverted:
            return String(
                localized: "validator.wakeEventInverted",
                defaultValue: "中途覚醒の終了時刻は開始時刻より後である必要があります"
            )
        }
    }
}

extension SleepRecordValidator {
    static func shortTime(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }
}
