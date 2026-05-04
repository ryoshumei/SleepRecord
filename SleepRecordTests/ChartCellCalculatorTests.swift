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
        let cells = calc.cells(forDay: date(2026, 5, 4, 0), sessions: [s])
        XCTAssertTrue(cells[23].inBed)
        XCTAssertFalse(cells[23].asleep)
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
}
