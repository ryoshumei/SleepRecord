import Foundation
import SwiftData

@MainActor
enum DataStore {
    static let shared: ModelContainer = {
        let schema = Schema([SleepSession.self])

        // Try CloudKit-backed first. SwiftData handles "user not signed in to iCloud"
        // automatically — the store loads fine and sync is just deferred.
        if let cloudContainer = try? makeCloudContainer(schema: schema) {
            return cloudContainer
        }

        // CloudKit init can fail if entitlements aren't provisioned (e.g., dev builds
        // without a team). Fall back to a separate local store so we don't reuse a
        // store the CloudKit attempt may have partially touched.
        if let localContainer = try? makeLocalContainer(schema: schema) {
            #if DEBUG
            print("CloudKit unavailable; using local-only store")
            #endif
            return localContainer
        }

        // Last resort: in-memory store so the app at least launches and surfaces
        // the failure visibly rather than crashing.
        #if DEBUG
        print("Both CloudKit and on-disk stores failed; using in-memory store")
        #endif
        return inMemory()
    }()

    private static func makeCloudContainer(schema: Schema) throws -> ModelContainer {
        let config = ModelConfiguration(
            "Cloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.ryan.sleeprecord")
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func makeLocalContainer(schema: Schema) throws -> ModelContainer {
        let config = ModelConfiguration(
            "Local",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func inMemory() -> ModelContainer {
        let schema = Schema([SleepSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
