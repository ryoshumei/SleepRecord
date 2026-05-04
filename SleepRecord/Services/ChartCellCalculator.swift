import Foundation

struct ChartCell: Equatable {
    let inBed: Bool
    let asleep: Bool
    static let empty = ChartCell(inBed: false, asleep: false)
}

struct ChartCellCalculator {
    let calendar: Calendar
    let timeZone: TimeZone

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
    }

    /// Returns 24 cells (one per hour 0..23) for the given day in the configured timezone.
    /// Rule: any-overlap = mark cell.
    func cells(forDay day: Date, sessions: [SleepSession]) -> [ChartCell] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return Array(repeating: .empty, count: 24)
        }

        var cells = Array(repeating: ChartCell.empty, count: 24)

        for session in sessions {
            // Build ranges defensively. Swift crashes on Range where upper < lower,
            // which can happen if (a) the session's bed/sleep window doesn't include
            // this day at all (bedInAt > dayEnd), or (b) user data is out of order
            // (e.g., correction sheet defaults make asleepAt > awakeAt for very short
            // sessions). Skip such ranges instead of crashing.
            let bedEnd = session.bedOutAt ?? dayEnd
            guard session.bedInAt < bedEnd else { continue }
            let bedRange = session.bedInAt..<bedEnd

            let sleepRange: Range<Date>? = {
                guard let s = session.asleepAt, let e = session.awakeAt, s < e else { return nil }
                return s..<e
            }()

            for hour in 0..<24 {
                guard let cellStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                      let cellEnd = calendar.date(byAdding: .hour, value: hour + 1, to: dayStart)
                else { continue }
                let cellRange = cellStart..<cellEnd

                let bedOverlap = rangesOverlap(bedRange, cellRange)
                let sleepOverlap = sleepRange.map { rangesOverlap($0, cellRange) } ?? false
                if bedOverlap || sleepOverlap {
                    cells[hour] = ChartCell(
                        inBed: cells[hour].inBed || bedOverlap,
                        asleep: cells[hour].asleep || sleepOverlap
                    )
                }
            }
        }
        return cells
    }

    private func rangesOverlap(_ a: Range<Date>, _ b: Range<Date>) -> Bool {
        a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
    }

    /// Notes for a given day, anchored to the session's wake day (bedOutAt) if
    /// present, otherwise its bed-in day. This avoids the same note appearing on
    /// both the night-of and morning-of rows for an overnight session.
    func notes(forDay day: Date, sessions: [SleepSession]) -> String {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return "" }
        return sessions
            .filter { s in
                guard !s.notes.isEmpty else { return false }
                let anchor = s.bedOutAt ?? s.bedInAt
                return anchor >= dayStart && anchor < dayEnd
            }
            .map(\.notes)
            .joined(separator: " / ")
    }
}
