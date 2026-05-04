import SwiftUI

struct MorningCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: SleepSession

    @State private var bedInAt: Date
    @State private var bedOutAt: Date
    @State private var asleepAt: Date
    @State private var awakeAt: Date
    @State private var notes: String

    init(session: SleepSession) {
        self.session = session
        let bedOut = session.bedOutAt ?? .now
        let defaultAsleep = session.asleepAt
            ?? Calendar.current.date(byAdding: .minute, value: 30, to: session.bedInAt)
            ?? session.bedInAt
        let defaultAwake = session.awakeAt
            ?? Calendar.current.date(byAdding: .minute, value: -15, to: bedOut)
            ?? bedOut
        self._bedInAt = State(initialValue: session.bedInAt)
        self._bedOutAt = State(initialValue: bedOut)
        self._asleepAt = State(initialValue: defaultAsleep)
        self._awakeAt = State(initialValue: defaultAwake)
        self._notes = State(initialValue: session.notes)
    }

    private var validationError: String? {
        SleepRecordValidator.validate(
            bedInAt: bedInAt, bedOutAt: bedOutAt,
            asleepAt: asleepAt, awakeAt: awakeAt
        )?.message(bedInAt: bedInAt, bedOutAt: bedOutAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("昨夜の記録（編集可能）") {
                    DatePicker(selection: $bedInAt, displayedComponents: [.date, .hourAndMinute]) {
                        Label("入床", systemImage: "bed.double.fill")
                            .foregroundStyle(.red)
                    }
                    DatePicker(selection: $bedOutAt, in: bedInAt..., displayedComponents: [.date, .hourAndMinute]) {
                        Label("起床", systemImage: "sun.max.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("何時頃に眠れましたか？") {
                    DatePicker("入眠時刻", selection: $asleepAt, in: bedInAt...bedOutAt, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("何時頃目が覚めましたか？") {
                    DatePicker("覚醒時刻", selection: $awakeAt, in: asleepAt...bedOutAt, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("備考") {
                    TextField("夜中に目覚めた、寝つきが悪い、など", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("☀️ おはようございます")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("後で") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .bold()
                        .disabled(validationError != nil)
                }
            }
        }
    }

    private func save() {
        session.bedInAt = bedInAt
        session.bedOutAt = bedOutAt
        session.asleepAt = TimeFormatter.snapTo5Min(asleepAt)
        session.awakeAt = TimeFormatter.snapTo5Min(awakeAt)
        session.notes = notes
        session.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
