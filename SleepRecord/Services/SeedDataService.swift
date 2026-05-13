#if DEBUG
import Foundation
import SwiftData

/// Generates a deterministic 30-day realistic sleep dataset for App Store screenshots.
/// Only available in DEBUG builds.
enum SeedDataService {
    static func populate(context: ModelContext, calendar: Calendar = .current) {
        clear(context: context)
        let inProgress = CommandLine.arguments.contains("-seedInProgress")
        if inProgress {
            let bedIn = Date().addingTimeInterval(-3600) // 1h ago
            context.insert(SleepSession(bedInAt: bedIn))
        }

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Deterministic pseudo-random: simple linear congruential generator seeded once.
        var seed: UInt64 = 20260510
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 11) & 0xFFFF_FFFF) / Double(UInt32.max)
        }
        func jitter(_ minutes: Int, range: Int) -> Int {
            return minutes + Int(next() * Double(range * 2)) - range
        }

        for daysAgo in 1...30 {
            guard let dayStart = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday)
            else { continue }

            // Bed-in: night before, around 22:30-23:30
            let bedInHour = 22
            let bedInMinute = jitter(45, range: 25)
            guard let bedInAt = calendar.date(
                bySettingHour: bedInHour, minute: max(0, min(59, bedInMinute)), second: 0,
                of: calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
            ) else { continue }

            // Asleep: 10-30 min after bed-in
            let sleepLatency = jitter(20, range: 10)
            let asleepAt = bedInAt.addingTimeInterval(TimeInterval(sleepLatency * 60))

            // Awake: ~6:30-7:30 the next morning
            let wakeHour = 7
            let wakeMinute = jitter(0, range: 30)
            let awakeAt = calendar.date(
                bySettingHour: wakeHour, minute: max(0, min(59, wakeMinute)), second: 0,
                of: dayStart
            ) ?? dayStart

            // Bed-out: 5-15 min after awake
            let lounge = jitter(10, range: 5)
            let bedOutAt = awakeAt.addingTimeInterval(TimeInterval(lounge * 60))

            // Notes on a few days for the 備考欄 column
            let notesPool = [
                "", "", "", "", "",
                "良く眠れた", "夢を見た", "途中で目覚めた",
                "寝つきが悪かった", "朝すっきり", ""
            ]
            let notes = notesPool[Int(next() * Double(notesPool.count)) % notesPool.count]

            let session = SleepSession(
                bedInAt: bedInAt,
                bedOutAt: bedOutAt,
                asleepAt: asleepAt,
                awakeAt: awakeAt,
                notes: notes
            )
            context.insert(session)

            // Add a mid-sleep wake event on ~20% of nights
            if next() < 0.2 {
                let wakeStart = asleepAt.addingTimeInterval(
                    TimeInterval((120 + Int(next() * 180)) * 60)
                )
                let wakeDuration = 5 + Int(next() * 25)
                let wakeEnd = wakeStart.addingTimeInterval(TimeInterval(wakeDuration * 60))
                if wakeEnd < awakeAt {
                    let event = WakeEvent(startedAt: wakeStart, endedAt: wakeEnd, session: session)
                    context.insert(event)
                }
            }
        }

        try? context.save()
    }

    static func clear(context: ModelContext) {
        if let sessions = try? context.fetch(FetchDescriptor<SleepSession>()) {
            for s in sessions { context.delete(s) }
        }
        if let events = try? context.fetch(FetchDescriptor<WakeEvent>()) {
            for e in events { context.delete(e) }
        }
        try? context.save()
    }
}
#endif
