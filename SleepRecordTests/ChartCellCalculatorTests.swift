import XCTest
import Foundation
@testable import SleepRecord

final class ChartCellCalculatorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = tz
        return cal.date(from: c)!
    }

    func testEmptyDay() {
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [])
        XCTAssertEqual(cells.count, 24)
        XCTAssertTrue(cells.allSatisfy { !$0.inBed && !$0.asleep })
    }

    func testSimpleNightSleep() {
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23),
            bedOutAt: date(2026, 5, 5, 7),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)

        let day1 = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(day1[23].inBed)
        XCTAssertTrue(day1[23].asleep)
        XCTAssertFalse(day1[22].inBed)

        let day2 = calc.cells(forDay: date(2026, 5, 5, 0), sessions: [s])
        for h in 0..<6 {
            XCTAssertTrue(day2[h].inBed, "hour \(h) should be in bed")
        }
        XCTAssertTrue(day2[6].inBed)
        XCTAssertTrue(day2[6].asleep)
        XCTAssertFalse(day2[7].inBed)
    }

    func testInProgressSession() {
        let s = SleepSession(bedInAt: date(2026, 5, 4, 23, 30))
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        // .now is at 5/5 02:00 — between bedIn (5/4 23:30) and end of 5/4 (24:00).
        let now = date(2026, 5, 5, 2, 0)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s], now: now)
        XCTAssertTrue(cells[23].inBed)
        XCTAssertFalse(cells[23].asleep)
    }

    func testInProgressSession_DoesNotPaintFutureDays() {
        // Regression: an open session used to paint every cell on every
        // subsequent day red because bedEnd defaulted to dayEnd of each
        // iteration. Now it caps at `now`, so days after `now` stay empty.
        let s = SleepSession(bedInAt: date(2026, 5, 13, 23, 29))
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let now = date(2026, 5, 13, 23, 30)   // user is in bed right now

        // Same day cells 0..22 empty, 23 in-bed
        let day13 = calc.cells(forDay: date(2026, 5, 13, 0), sessions: [s], now: now)
        XCTAssertTrue(day13[23].inBed)
        for h in 0..<23 { XCTAssertFalse(day13[h].inBed, "hour \(h) on bed-day shouldn't be in bed") }

        // All future days completely empty — this was the bug
        for offset in 1...18 {
            let day = calc.cells(
                forDay: date(2026, 5, 13 + offset, 0),
                sessions: [s],
                now: now
            )
            XCTAssertTrue(
                day.allSatisfy { !$0.inBed && !$0.asleep },
                "day +\(offset) should be empty, but at least one cell is in-bed"
            )
        }
    }

    func testInProgressSession_PaintsHoursUpToNow() {
        // User went to bed at 23:30 on 5/13; it's now 02:00 on 5/14 and they
        // haven't tapped おはよう yet. Expect hour 23 of 5/13 + hours 0,1 of
        // 5/14 to be in-bed; hour 2 and beyond of 5/14 should be clear.
        let s = SleepSession(bedInAt: date(2026, 5, 13, 23, 30))
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let now = date(2026, 5, 14, 2, 0)

        let day14 = calc.cells(forDay: date(2026, 5, 14, 0), sessions: [s], now: now)
        XCTAssertTrue(day14[0].inBed)
        XCTAssertTrue(day14[1].inBed)
        XCTAssertFalse(day14[2].inBed, "hour 2 is after .now — should not be in-bed")
        for h in 3..<24 {
            XCTAssertFalse(day14[h].inBed, "hour \(h) is after .now — should not be in-bed")
        }
    }

    func testMultipleSessionsSameDay() {
        let nap = SleepSession(
            bedInAt: date(2026, 5, 4, 13),
            bedOutAt: date(2026, 5, 4, 14),
            asleepAt: date(2026, 5, 4, 13, 10),
            awakeAt: date(2026, 5, 4, 13, 50)
        )
        let night = SleepSession(
            bedInAt: date(2026, 5, 4, 23),
            bedOutAt: date(2026, 5, 5, 7),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [nap, night])
        XCTAssertTrue(cells[13].inBed)
        XCTAssertTrue(cells[13].asleep)
        XCTAssertTrue(cells[23].inBed)
    }

    func testPartialHourCounts() {
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23, 59),
            bedOutAt: date(2026, 5, 5, 0, 1)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let day1 = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(day1[23].inBed)
        let day2 = calc.cells(forDay: date(2026, 5, 5, 0), sessions: [s])
        XCTAssertTrue(day2[0].inBed)
    }

    func testSessionAfterDay_NoCrash() {
        // Session is for 5/5; render 5/3. bedInAt > dayEnd would crash naive Range.
        let s = SleepSession(
            bedInAt: date(2026, 5, 5, 23),
            bedOutAt: date(2026, 5, 6, 7)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 3, 0), sessions: [s])
        XCTAssertEqual(cells.count, 24)
        XCTAssertTrue(cells.allSatisfy { !$0.inBed && !$0.asleep })
    }

    func testInProgressSessionFromFuture_NoCrash() {
        // bedInAt is in the future relative to the rendered day (no bedOutAt).
        let s = SleepSession(bedInAt: date(2026, 5, 6, 23, 30))
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(cells.allSatisfy { !$0.inBed && !$0.asleep })
    }

    // MARK: notes(forDay:)

    func testNotes_ReturnsEmptyWhenNoSessions() {
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        XCTAssertEqual(calc.notes(forDay: date(2026, 5, 4, 0), sessions: []), "")
    }

    func testNotes_AnchoredToWakeDay() {
        // Session: bed 5/3 23:00 → wake 5/4 7:00, notes "寝つき悪い"
        // Notes should appear on 5/4 (wake day), not 5/3 (bed-in day).
        let s = SleepSession(
            bedInAt: date(2026, 5, 3, 23),
            bedOutAt: date(2026, 5, 4, 7),
            asleepAt: date(2026, 5, 3, 23, 30),
            awakeAt: date(2026, 5, 4, 6, 30),
            notes: "寝つき悪い"
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        XCTAssertEqual(calc.notes(forDay: date(2026, 5, 3, 0), sessions: [s]), "")
        XCTAssertEqual(calc.notes(forDay: date(2026, 5, 4, 0), sessions: [s]), "寝つき悪い")
    }

    func testNotes_FallsBackToBedInDayWhenNoBedOut() {
        // In-progress session has no bedOutAt — anchor to bedInAt.
        let s = SleepSession(bedInAt: date(2026, 5, 4, 23, 30), notes: "進行中メモ")
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        XCTAssertEqual(calc.notes(forDay: date(2026, 5, 4, 0), sessions: [s]), "進行中メモ")
    }

    func testNotes_JoinsMultipleSessionsSameDay() {
        let s1 = SleepSession(
            bedInAt: date(2026, 5, 4, 13),
            bedOutAt: date(2026, 5, 4, 14),
            notes: "昼寝"
        )
        let s2 = SleepSession(
            bedInAt: date(2026, 5, 3, 23),
            bedOutAt: date(2026, 5, 4, 7),
            notes: "夜中起きた"
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let notes = calc.notes(forDay: date(2026, 5, 4, 0), sessions: [s1, s2])
        XCTAssertTrue(notes.contains("昼寝"))
        XCTAssertTrue(notes.contains("夜中起きた"))
    }

    func testNotes_SkipsEmptyNotes() {
        let s1 = SleepSession(
            bedInAt: date(2026, 5, 3, 23),
            bedOutAt: date(2026, 5, 4, 7),
            notes: ""
        )
        let s2 = SleepSession(
            bedInAt: date(2026, 5, 4, 13),
            bedOutAt: date(2026, 5, 4, 14),
            notes: "昼寝"
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        XCTAssertEqual(calc.notes(forDay: date(2026, 5, 4, 0), sessions: [s1, s2]), "昼寝")
    }

    func testInvertedSleepRange_IgnoredNoCrash() {
        // asleepAt > awakeAt (e.g., user accidentally inverted slider). Should not crash.
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23),
            bedOutAt: date(2026, 5, 5, 7),
            asleepAt: date(2026, 5, 5, 6, 30),
            awakeAt: date(2026, 5, 5, 0, 30)
        )
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        // Bed range is valid → 23 cell should be in bed; sleep is invalid → no asleep marking.
        XCTAssertTrue(cells[23].inBed)
        XCTAssertFalse(cells[23].asleep)
    }

    // MARK: wake events

    func testCells_WakeEventSuppressesAsleep() {
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23, 0),
            bedOutAt: date(2026, 5, 5, 7, 0),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        // 3:00–3:30 wake event — hour 3 cell should be in-bed but NOT asleep.
        let event = WakeEvent(
            startedAt: date(2026, 5, 5, 3, 0),
            endedAt: date(2026, 5, 5, 3, 30),
            session: s
        )
        s.wakeEvents = [event]

        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 5, 0, 0), sessions: [s])

        XCTAssertTrue(cells[3].inBed)
        XCTAssertFalse(cells[3].asleep, "wake event should suppress asleep on hour 3")
        XCTAssertTrue(cells[2].inBed)
        XCTAssertTrue(cells[2].asleep)
    }

    func testCells_MultipleWakeEvents() {
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23, 0),
            bedOutAt: date(2026, 5, 5, 7, 0),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30)
        )
        s.wakeEvents = [
            WakeEvent(startedAt: date(2026, 5, 5, 1, 0),
                      endedAt:   date(2026, 5, 5, 1, 15), session: s),
            WakeEvent(startedAt: date(2026, 5, 5, 4, 0),
                      endedAt:   date(2026, 5, 5, 4, 45), session: s)
        ]
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let cells = calc.cells(forDay: date(2026, 5, 5, 0, 0), sessions: [s])

        XCTAssertFalse(cells[1].asleep)
        XCTAssertFalse(cells[4].asleep)
        XCTAssertTrue(cells[3].asleep, "no event in hour 3 — should still be asleep")
        XCTAssertTrue(cells[2].asleep, "no event in hour 2")
    }

    func testNotes_PrependsSummary() {
        let s = SleepSession(
            bedInAt: date(2026, 5, 4, 23, 0),
            bedOutAt: date(2026, 5, 5, 7, 0),
            asleepAt: date(2026, 5, 4, 23, 30),
            awakeAt: date(2026, 5, 5, 6, 30),
            notes: "夜中トイレ"
        )
        s.wakeEvents = [
            WakeEvent(startedAt: date(2026, 5, 5, 3, 0),
                      endedAt:   date(2026, 5, 5, 3, 30), session: s)
        ]
        let calc = ChartCellCalculator(calendar: cal, timeZone: tz)
        let result = calc.notes(forDay: date(2026, 5, 5, 0, 0), sessions: [s])
        XCTAssertTrue(result.contains("覚醒×1") || result.contains("Wakes×1"))
        XCTAssertTrue(result.contains("30"), "summary should mention 30 minutes")
        XCTAssertTrue(result.contains("夜中トイレ"))
    }
}
