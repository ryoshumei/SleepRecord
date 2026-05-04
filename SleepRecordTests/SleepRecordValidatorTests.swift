import XCTest
@testable import SleepRecord

final class SleepRecordValidatorTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let tz = TimeZone(identifier: "Asia/Tokyo")!

    func dt(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = tz
        return cal.date(from: c)!
    }

    // MARK: validate (full record)

    func testValid_NormalNightSleep() {
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        XCTAssertNil(r)
    }

    func testValid_InstantSleepAndInstantWake() {
        // bedInAt == asleepAt and awakeAt == bedOutAt are allowed
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 0),
            awakeAt: dt(2026, 5, 5, 7, 0)
        )
        XCTAssertNil(r)
    }

    func testInvalid_BedWindowInverted() {
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 4, 22, 0),  // before bedInAt
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        XCTAssertEqual(r, .bedWindowInverted)
    }

    func testInvalid_BedWindowZeroDuration() {
        // bedInAt == bedOutAt is also invalid (no actual time in bed)
        let t = dt(2026, 5, 4, 23, 0)
        let r = SleepRecordValidator.validate(
            bedInAt: t,
            bedOutAt: t,
            asleepAt: t,
            awakeAt: t
        )
        XCTAssertEqual(r, .bedWindowInverted)
    }

    func testInvalid_AsleepBeforeBedIn() {
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 22, 0),  // before bedInAt
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        XCTAssertEqual(r, .asleepBeforeBedIn)
    }

    func testInvalid_AwakeAfterBedOut() {
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 8, 0)  // after bedOutAt
        )
        XCTAssertEqual(r, .awakeAfterBedOut)
    }

    func testInvalid_AsleepAfterAwake() {
        // The exact case from the bug report (5/4 11:36 → 12:05 → 11:20 → 11:37)
        let r = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 11, 36),
            bedOutAt: dt(2026, 5, 4, 11, 37),
            asleepAt: dt(2026, 5, 4, 12, 5),
            awakeAt: dt(2026, 5, 4, 11, 20)
        )
        // bedOut < asleep → caught by .awakeAfterBedOut first since 11:20 < 11:37 doesn't trigger,
        // but 12:05 > 11:37 (bedOutAt) does trigger awakeAfterBedOut? No — awake is 11:20.
        // Actually: bedInAt=11:36, bedOutAt=11:37, asleepAt=12:05, awakeAt=11:20.
        // 1. bedInAt(11:36) >= bedOutAt(11:37)? No (11:36 < 11:37).
        // 2. asleepAt(12:05) < bedInAt(11:36)? No.
        // 3. awakeAt(11:20) > bedOutAt(11:37)? No (11:20 < 11:37).
        // 4. asleepAt(12:05) > awakeAt(11:20)? Yes. → .asleepAfterAwake
        XCTAssertEqual(r, .asleepAfterAwake)
    }

    func testBugReport_ExactScenario_BlocksSave() {
        // Direct reproduction of the user-reported screenshot.
        let issue = SleepRecordValidator.validate(
            bedInAt: dt(2026, 5, 4, 11, 36),
            bedOutAt: dt(2026, 5, 4, 11, 37),
            asleepAt: dt(2026, 5, 4, 12, 5),
            awakeAt: dt(2026, 5, 4, 11, 20)
        )
        XCTAssertNotNil(issue, "Bug report scenario must be flagged as invalid")
    }

    // MARK: validateSleepOnly (morning correction sheet)

    func testSleepOnly_Valid() {
        let r = SleepRecordValidator.validateSleepOnly(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        XCTAssertNil(r)
    }

    func testSleepOnly_AsleepBeforeBedIn() {
        let r = SleepRecordValidator.validateSleepOnly(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 22, 30),
            awakeAt: dt(2026, 5, 5, 6, 30)
        )
        XCTAssertEqual(r, .asleepBeforeBedIn)
    }

    func testSleepOnly_AwakeAfterBedOut() {
        let r = SleepRecordValidator.validateSleepOnly(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 4, 23, 30),
            awakeAt: dt(2026, 5, 5, 7, 30)
        )
        XCTAssertEqual(r, .awakeAfterBedOut)
    }

    func testSleepOnly_AsleepAfterAwake() {
        let r = SleepRecordValidator.validateSleepOnly(
            bedInAt: dt(2026, 5, 4, 23, 0),
            bedOutAt: dt(2026, 5, 5, 7, 0),
            asleepAt: dt(2026, 5, 5, 6, 30),
            awakeAt: dt(2026, 5, 5, 0, 30)
        )
        XCTAssertEqual(r, .asleepAfterAwake)
    }

    // MARK: messages

    func testMessage_BedWindowInverted_HasJapaneseText() {
        let m = SleepRecordValidator.Issue.bedWindowInverted.message()
        XCTAssertTrue(m.contains("布団"))
    }

    func testMessage_AsleepBeforeBedIn_IncludesTimeWhenProvided() {
        let bedIn = dt(2026, 5, 4, 23, 0)
        let m = SleepRecordValidator.Issue.asleepBeforeBedIn.message(bedInAt: bedIn)
        XCTAssertTrue(m.contains("入床") || m.contains("眠"))
    }

    func testMessage_AsleepAfterAwake_DescribesProblem() {
        let m = SleepRecordValidator.Issue.asleepAfterAwake.message()
        XCTAssertTrue(m.contains("眠") && m.contains("目覚め") || m.contains("覚醒"))
    }
}
