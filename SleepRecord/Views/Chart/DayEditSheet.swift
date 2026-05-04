import SwiftUI
import SwiftData

struct DayEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [SleepSession]

    let date: Date

    @State private var bedInAt: Date = .now
    @State private var bedOutAt: Date = .now
    @State private var asleepAt: Date = .now
    @State private var awakeAt: Date = .now
    @State private var notes: String = ""
    @State private var existing: SleepSession?

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            Form {
                Section("時刻") {
                    DatePicker("布団に入った", selection: $bedInAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("眠った", selection: $asleepAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("目覚めた", selection: $awakeAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("布団から出た", selection: $bedOutAt, displayedComponents: [.date, .hourAndMinute])
                }
                Section("備考") {
                    TextField("メモ", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if existing != nil {
                    Section {
                        Button("この日の記録を削除", role: .destructive) {
                            if let e = existing {
                                modelContext.delete(e)
                                try? modelContext.save()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(TimeFormatter.dateLabel.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.bold() }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let match = allSessions.first { s in
            let bedEnd = s.bedOutAt ?? dayEnd
            guard s.bedInAt < bedEnd else { return false }
            return s.bedInAt < dayEnd && bedEnd > dayStart
        }
        existing = match

        if let s = match {
            bedInAt = s.bedInAt
            bedOutAt = s.bedOutAt ?? s.bedInAt
            asleepAt = s.asleepAt ?? s.bedInAt
            awakeAt = s.awakeAt ?? s.bedOutAt ?? s.bedInAt
            notes = s.notes
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
            bedInAt = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday) ?? dayStart
            asleepAt = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: yesterday) ?? dayStart
            awakeAt = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: dayStart) ?? dayStart
            bedOutAt = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dayStart) ?? dayStart
            notes = ""
        }
    }

    private func save() {
        if let s = existing {
            s.bedInAt = bedInAt
            s.bedOutAt = bedOutAt
            s.asleepAt = asleepAt
            s.awakeAt = awakeAt
            s.notes = notes
            s.updatedAt = .now
        } else {
            let s = SleepSession(
                bedInAt: bedInAt, bedOutAt: bedOutAt,
                asleepAt: asleepAt, awakeAt: awakeAt, notes: notes
            )
            modelContext.insert(s)
        }
        try? modelContext.save()
        dismiss()
    }
}
