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

    /// True iff the active session has at least one open WakeEvent (i.e. user
    /// tapped 目覚めた but hasn't tapped 再び眠る yet).
    static func isAwakeMidSleep(activeSession: SleepSession?) -> Bool {
        guard let s = activeSession else { return false }
        return s.wakeEvents.contains { $0.isOpen }
    }
}
