import XCTest
@testable import SleepRecord

final class SleepStateMachineTests: XCTestCase {
    func testEmpty_NoSessions() {
        XCTAssertEqual(SleepStateMachine.state(activeSession: nil), .empty)
    }

    func testInBed_HasActiveSession() {
        let s = SleepSession(bedInAt: .now)
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .inBed)
    }

    func testCorrectionPending_BedOutSetButNoSleepData() {
        let s = SleepSession(bedInAt: .now, bedOutAt: .now)
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .correctionPending)
    }

    func testCompleted_AllFieldsSet() {
        let s = SleepSession(
            bedInAt: .now, bedOutAt: .now,
            asleepAt: .now, awakeAt: .now
        )
        XCTAssertEqual(SleepStateMachine.state(activeSession: s), .completed)
    }
}
