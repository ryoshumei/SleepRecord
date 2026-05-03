import Foundation
import SwiftData

@MainActor
enum DataStore {
    static let shared: ModelContainer = {
        let schema = Schema([SleepSession.self])

        // Try CloudKit-backed; on failure (dev/no entitlement), fall back to local.
        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.ryan.sleeprecord")
            )
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            #if DEBUG
            print("CloudKit container failed, falling back to local-only: \(error)")
            #endif
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
    }()

    static func inMemory() -> ModelContainer {
        let schema = Schema([SleepSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
