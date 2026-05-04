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
        }
    }
}

extension SleepRecordValidator {
    static func shortTime(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }
}
