import Foundation
import SwiftData

@Model
final class SleepSession {
    // CloudKit requires all non-optional attributes to have defaults, and does not allow .unique constraints.
    var id: UUID = UUID()
    var bedInAt: Date = Date.distantPast
    var bedOutAt: Date?
    var asleepAt: Date?
    var awakeAt: Date?
    var notes: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(
        id: UUID = UUID(),
        bedInAt: Date,
        bedOutAt: Date? = nil,
        asleepAt: Date? = nil,
        awakeAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bedInAt = bedInAt
        self.bedOutAt = bedOutAt
        self.asleepAt = asleepAt
        self.awakeAt = awakeAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isInProgress: Bool { bedOutAt == nil }
    var isFullyRecorded: Bool { bedOutAt != nil && asleepAt != nil && awakeAt != nil }
}
