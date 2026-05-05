import XCTest
@testable import SleepRecord

final class WakeEventTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func dt(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = tz
        return cal.date(from: c)!
    }

    func testOpen_WhenEndedAtIsNil() {
        let e = WakeEvent(startedAt: dt(2026, 5, 5, 3, 0))
        XCTAssertTrue(e.isOpen)
        XCTAssertNil(e.durationMinutes)
    }

    func testClosed_DurationIsCorrect() {
        let e = WakeEvent(
            startedAt: dt(2026, 5, 5, 3, 0),
            endedAt: dt(2026, 5, 5, 3, 30)
        )
        XCTAssertFalse(e.isOpen)
        XCTAssertEqual(e.durationMinutes, 30)
    }

    func testClosed_InvertedTimes_DurationNil() {
        // Defensive: endedAt before startedAt should not crash and should be
        // surfaced as nil duration so UI can avoid showing nonsense.
        let e = WakeEvent(
            startedAt: dt(2026, 5, 5, 3, 30),
            endedAt: dt(2026, 5, 5, 3, 0)
        )
        XCTAssertFalse(e.isOpen)
        XCTAssertNil(e.durationMinutes)
    }
}
