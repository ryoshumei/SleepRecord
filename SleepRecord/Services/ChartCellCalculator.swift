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
            let bedRange = session.bedInAt..<(session.bedOutAt ?? dayEnd)
            let sleepRange: Range<Date>? = {
                guard let s = session.asleepAt, let e = session.awakeAt else { return nil }
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
}
