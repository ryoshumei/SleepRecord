import Foundation
import SwiftData

@Model
final class WakeEvent {
    // CloudKit requires all non-optional attributes to have property-level defaults.
    var id: UUID = UUID()
    var startedAt: Date = Date.distantPast
    var endedAt: Date?            // nil = still awake (open event)
    var session: SleepSession?    // CloudKit-friendly optional inverse
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        session: SleepSession? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.session = session
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isOpen: Bool { endedAt == nil }

    /// Duration in minutes; nil for open events.
    var durationMinutes: Int? {
        guard let end = endedAt, end > startedAt else { return nil }
        return Int(end.timeIntervalSince(startedAt) / 60)
    }
}
