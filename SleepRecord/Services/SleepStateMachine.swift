import Foundation

enum SleepState: Equatable {
    case empty
    case inBed
    case correctionPending
    case completed
}

enum SleepStateMachine {
    /// Active session = the most recent session for the current sleep-day window.
    /// Caller passes nil if no recent session is in scope.
    static func state(activeSession: SleepSession?) -> SleepState {
        guard let s = activeSession else { return .empty }
        if s.bedOutAt == nil { return .inBed }
        if s.asleepAt == nil || s.awakeAt == nil { return .correctionPending }
        return .completed
    }
}
