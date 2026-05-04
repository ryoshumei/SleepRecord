import Foundation
import SwiftData

@MainActor
enum DataStore {
    static let shared: ModelContainer = {
        let schema = Schema([SleepSession.self])

        // CloudKit's mirroring delegate hard-traps (brk #1) inside the CloudKit
        // framework when the user isn't signed in — try/catch around ModelContainer
        // can't catch that. So we MUST check iCloud account availability before
        // even attempting to enable CloudKit, not after.
        if isICloudAvailable(), let cloudContainer = try? makeCloudContainer(schema: schema) {
            return cloudContainer
        }

        if let localContainer = try? makeLocalContainer(schema: schema) {
            #if DEBUG
            print("Using local-only store (iCloud not signed in or CloudKit init failed)")
            #endif
            return localContainer
        }

        #if DEBUG
        print("On-disk store failed; falling back to in-memory store")
        #endif
        return inMemory()
    }()

    /// True if a real iCloud account is signed in on the device. The simulator
    /// without account, dev builds without entitlement, and signed-out users all
    /// return false — in which case we must NOT engage the CloudKit mirroring
    /// delegate.
    private static func isICloudAvailable() -> Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

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
