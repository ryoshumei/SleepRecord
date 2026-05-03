import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bedtimeReminderEnabled") private var reminderEnabled = true
    @AppStorage("bedtimeReminderHour") private var reminderHour = 22
    @AppStorage("bedtimeReminderMinute") private var reminderMinute = 30

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var iCloudAvailable: Bool = FileManager.default.ubiquityIdentityToken != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("就寝時刻リマインダー") {
                    Toggle("通知を有効にする", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, new in
                            Task { await applyReminder(enabled: new) }
                        }
                    if reminderEnabled {
                        DatePicker(
                            "通知時刻",
                            selection: Binding(
                                get: { dateForHM(reminderHour, reminderMinute) },
                                set: { d in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                                    reminderHour = comps.hour ?? 22
                                    reminderMinute = comps.minute ?? 30
                                    Task { await applyReminder(enabled: true) }
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                    HStack {
                        Text("通知許可状態")
                        Spacer()
                        Text(notificationStatus.label).foregroundStyle(.secondary)
                    }
                }

                Section("iCloud 同期") {
                    HStack {
                        Image(systemName: iCloudAvailable ? "checkmark.icloud.fill" : "xmark.icloud.fill")
                            .foregroundStyle(iCloudAvailable ? .green : .secondary)
                        Text(iCloudAvailable ? "iCloud で同期中" : "iCloud アカウント未設定")
                    }
                    if !iCloudAvailable {
                        Text("「設定 > Apple ID > iCloud」でアカウントを有効にすると、データが iCloud に同期されます。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("このアプリについて") {
                    HStack { Text("バージョン"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
            .task {
                notificationStatus = await NotificationScheduler.currentAuthorizationStatus()
            }
        }
    }

    private func dateForHM(_ h: Int, _ m: Int) -> Date {
        var comps = DateComponents(); comps.hour = h; comps.minute = m
        return Calendar.current.date(from: comps) ?? .now
    }

    private func applyReminder(enabled: Bool) async {
        if enabled {
            await NotificationScheduler.scheduleBedtimeReminder(
                at: reminderHour, minute: reminderMinute
            )
        } else {
            NotificationScheduler.cancelBedtimeReminder()
        }
        notificationStatus = await NotificationScheduler.currentAuthorizationStatus()
    }
}

private extension UNAuthorizationStatus {
    var label: String {
        switch self {
        case .authorized: return "許可済み"
        case .denied: return "拒否"
        case .notDetermined: return "未確認"
        case .provisional: return "暫定"
        case .ephemeral: return "一時"
        @unknown default: return "不明"
        }
    }
}
