import SwiftUI
import SwiftData

@main
struct SleepRecordApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(DataStore.shared)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "moon.zzz.fill") }
            ChartView()
                .tabItem { Label("チャート", systemImage: "chart.bar.doc.horizontal") }
        }
        .tint(.purple)
    }
}
