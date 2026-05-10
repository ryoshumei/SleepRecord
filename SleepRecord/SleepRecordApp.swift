import SwiftUI
import SwiftData

@main
struct SleepRecordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    #if DEBUG
                    if CommandLine.arguments.contains("-seedDemo") {
                        SeedDataService.populate(context: DataStore.shared.mainContext)
                    }
                    #endif
                }
        }
        .modelContainer(DataStore.shared)
    }
}

struct RootView: View {
    @State private var selectedTab: Int = {
        #if DEBUG
        if CommandLine.arguments.contains("-startTab") {
            if let idx = CommandLine.arguments.firstIndex(of: "-startTab"),
               idx + 1 < CommandLine.arguments.count,
               let n = Int(CommandLine.arguments[idx + 1]) {
                return n
            }
        }
        #endif
        return 0
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "moon.zzz.fill") }
                .tag(0)
            ChartView()
                .tabItem { Label("チャート", systemImage: "chart.bar.doc.horizontal") }
                .tag(1)
        }
        .tint(.purple)
    }
}
