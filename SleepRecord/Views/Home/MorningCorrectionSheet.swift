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
        // bedOut may equal bedIn (e.g. user double-tapped) or even be earlier in
        // edge cases. Clamp it to be at least bedIn so downstream picker bounds
        // are valid; the user can correct it via the editable bedOut picker.
        let rawBedOut = session.bedOutAt ?? .now
        let bedOut = max(rawBedOut, session.bedInAt)
        // Default asleep/awake midway between bedIn and bedOut when no record
        // exists yet. If the bed window is too short to hold the +30/-15 defaults,
        // clamp to the bed window itself.
        let defaultAsleep = MorningCorrectionSheet.clamp(
            session.asleepAt ?? Calendar.current.date(byAdding: .minute, value: 30, to: session.bedInAt) ?? session.bedInAt,
            to: session.bedInAt...bedOut
        )
        let defaultAwake = MorningCorrectionSheet.clamp(
            session.awakeAt ?? Calendar.current.date(byAdding: .minute, value: -15, to: bedOut) ?? bedOut,
            to: defaultAsleep...bedOut
        )
        self._bedInAt = State(initialValue: session.bedInAt)
        self._bedOutAt = State(initialValue: bedOut)
        self._asleepAt = State(initialValue: defaultAsleep)
        self._awakeAt = State(initialValue: defaultAwake)
        self._notes = State(initialValue: session.notes)
    }

    static func clamp(_ value: Date, to range: ClosedRange<Date>) -> Date {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var validationError: String? {
        if let timeIssue = SleepRecordValidator.validate(
            bedInAt: bedInAt, bedOutAt: bedOutAt,
            asleepAt: asleepAt, awakeAt: awakeAt
        ) {
            return timeIssue.message(bedInAt: bedInAt, bedOutAt: bedOutAt)
        }
        let events = session.wakeEvents.map {
            (startedAt: $0.startedAt, endedAt: $0.endedAt)
        }
        if let wakeIssue = SleepRecordValidator.validateWakeEvents(
            events, bedInAt: bedInAt, bedOutAt: bedOutAt
        ) {
            return wakeIssue.message()
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("昨夜の記録（編集可能）") {
                    DatePicker(selection: $bedInAt, displayedComponents: [.date, .hourAndMinute]) {
                        Label("入床", systemImage: "bed.double.fill")
                            .foregroundStyle(.red)
                    }
                    DatePicker(selection: $bedOutAt, displayedComponents: [.date, .hourAndMinute]) {
                        Label("起床", systemImage: "sun.max.fill")
                            .foregroundStyle(.orange)
                    }
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

                Section("中途覚醒") {
                    if session.wakeEvents.isEmpty {
                        Text("（なし）")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(session.wakeEvents.sorted(by: { $0.startedAt < $1.startedAt })) { event in
                            wakeEventRow(event)
                        }
                    }
                    Button {
                        addWakeEvent()
                    } label: {
                        Label("追加", systemImage: "plus.circle.fill")
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

    @ViewBuilder
    private func wakeEventRow(_ event: WakeEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                DatePicker("", selection: Binding(
                    get: { event.startedAt },
                    set: { event.startedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                DatePicker("", selection: Binding(
                    get: { event.endedAt ?? event.startedAt },
                    set: { event.endedAt = $0; event.updatedAt = .now }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            }
            Spacer()
            Button(role: .destructive) {
                deleteWakeEvent(event)
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private func addWakeEvent() {
        let mid = bedInAt.addingTimeInterval(bedOutAt.timeIntervalSince(bedInAt) / 2)
        let end = mid.addingTimeInterval(10 * 60)
        let event = WakeEvent(
            startedAt: mid,
            endedAt: end,
            session: session
        )
        modelContext.insert(event)
        session.wakeEvents.append(event)
        session.updatedAt = .now
    }

    private func deleteWakeEvent(_ event: WakeEvent) {
        if let idx = session.wakeEvents.firstIndex(where: { $0.id == event.id }) {
            session.wakeEvents.remove(at: idx)
        }
        modelContext.delete(event)
        session.updatedAt = .now
    }
}
