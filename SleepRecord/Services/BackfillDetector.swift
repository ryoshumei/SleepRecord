import Foundation

struct BackfillResult {
    let needsBackfill: Bool
    let suggestedBedInAt: Date?
}

enum BackfillDetector {
    static func detect(
        now: Date,
        activeSession: SleepSession?,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> BackfillResult {
        if activeSession != nil {
            return BackfillResult(needsBackfill: false, suggestedBedInAt: nil)
        }
        var cal = calendar
        cal.timeZone = timeZone
        let today = cal.startOfDay(for: now)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let suggested = cal.date(byAdding: .hour, value: 23, to: yesterday)
        else {
            return BackfillResult(needsBackfill: true, suggestedBedInAt: nil)
        }
        return BackfillResult(needsBackfill: true, suggestedBedInAt: suggested)
    }
}
