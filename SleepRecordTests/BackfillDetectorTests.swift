import XCTest
@testable import SleepRecord

final class BackfillDetectorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func dt(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        c.timeZone = tz
        return cal.date(from: c)!
    }

    func testNoActiveSession_NeedsBackfill() {
        let now = dt(2026, 5, 4, 7)
        let result = BackfillDetector.detect(
            now: now,
            activeSession: nil,
            calendar: cal,
            timeZone: tz
        )
        XCTAssertTrue(result.needsBackfill)
        XCTAssertEqual(result.suggestedBedInAt, dt(2026, 5, 3, 23))
    }

    func testActiveSessionExists_NoBackfill() {
        let s = SleepSession(bedInAt: dt(2026, 5, 3, 23))
        let result = BackfillDetector.detect(
            now: dt(2026, 5, 4, 7),
            activeSession: s,
            calendar: cal,
            timeZone: tz
        )
        XCTAssertFalse(result.needsBackfill)
    }
}
