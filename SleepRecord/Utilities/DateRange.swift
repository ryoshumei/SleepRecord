import Foundation

enum DateRange {
    /// Default PDF range: 1 month back from today (inclusive).
    static func defaultPDFRange(now: Date = .now, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        return (start, end)
    }

    /// All days from start to end (inclusive), at startOfDay.
    static func enumerate(start: Date, end: Date, calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }
}
