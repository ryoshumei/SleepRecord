import SwiftUI

struct MorningCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: SleepSession

    @State private var asleepAt: Date
    @State private var awakeAt: Date
    @State private var notes: String

    init(session: SleepSession) {
        self.session = session
        let defaultAsleep = session.asleepAt
            ?? Calendar.current.date(byAdding: .minute, value: 30, to: session.bedInAt)
            ?? session.bedInAt
        let bedOut = session.bedOutAt ?? .now
        let defaultAwake = session.awakeAt
            ?? Calendar.current.date(byAdding: .minute, value: -15, to: bedOut)
            ?? bedOut
        self._asleepAt = State(initialValue: defaultAsleep)
        self._awakeAt = State(initialValue: defaultAwake)
        self._notes = State(initialValue: session.notes)
    }

    private var validationError: String? {
        let bedOut = session.bedOutAt ?? .now
        return SleepRecordValidator.validateSleepOnly(
            bedInAt: session.bedInAt, bedOutAt: bedOut,
            asleepAt: asleepAt, awakeAt: awakeAt
        )?.message(bedInAt: session.bedInAt, bedOutAt: bedOut)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("昨夜の記録").font(.headline)
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "bed.double.fill").foregroundStyle(.red)
                        Text("入床: \(session.bedInAt, format: .dateTime.hour().minute())")
                        Spacer()
                        if let o = session.bedOutAt {
                            Text("起床: \(o, format: .dateTime.hour().minute())")
                        }
                    }.font(.subheadline)
                }

                Section("何時頃に眠れましたか？") {
                    DatePicker("入眠時刻", selection: $asleepAt, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }

                Section("何時頃目が覚めましたか？") {
                    DatePicker("覚醒時刻", selection: $awakeAt, displayedComponents: [.hourAndMinute])
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
        session.asleepAt = TimeFormatter.snapTo5Min(asleepAt)
        session.awakeAt = TimeFormatter.snapTo5Min(awakeAt)
        session.notes = notes
        session.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
