import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepSession.bedInAt, order: .reverse) private var sessions: [SleepSession]
    @State private var showCorrectionSheet = false
    @State private var showBackfillSheet = false
    @State private var backfillSuggested: Date = .now
    @State private var now: Date = .now
    @State private var showSettings = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var activeSession: SleepSession? {
        sessions.first { !isCompleted($0) }
    }

    var state: SleepState {
        SleepStateMachine.state(activeSession: activeSession)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: state == .inBed
                        ? [Color(red: 0.05, green: 0.05, blue: 0.17), Color(red: 0.13, green: 0.10, blue: 0.30)]
                        : [Color(red: 0.05, green: 0.05, blue: 0.17), Color(red: 0.20, green: 0.15, blue: 0.40)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 16)
                    Text("SLEEP RHYTHM")
                        .font(.caption2).tracking(3).foregroundStyle(.white.opacity(0.55))
                    Text(now, format: .dateTime.year().month().day().weekday())
                        .font(.callout).foregroundStyle(.white.opacity(0.85))
                    Text(now, format: .dateTime.hour().minute())
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(.white)

                    Spacer()

                    bigButton

                    if case .inBed = state, let s = activeSession {
                        Text("就寝中: \(s.bedInAt, format: .dateTime.hour().minute()) 〜")
                            .font(.footnote).foregroundStyle(.white.opacity(0.6))
                    }

                    if case .inBed = state {
                        if SleepStateMachine.isAwakeMidSleep(activeSession: activeSession) {
                            Button("☀️ おはよう") { tapMorning() }
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.top, 32)
                        } else {
                            Button("🌗 目覚めた") { tapWokeUp() }
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.top, 32)
                        }
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCorrectionSheet) {
                if let s = activeSession {
                    MorningCorrectionSheet(session: s)
                }
            }
            .sheet(isPresented: $showBackfillSheet) {
                BackfillSheet(suggestedBedInAt: backfillSuggested) { bedInAt in
                    let s = SleepSession(bedInAt: bedInAt, bedOutAt: now)
                    modelContext.insert(s)
                    try? modelContext.save()
                    showCorrectionSheet = true
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onReceive(timer) { now = $0 }
            .onAppear { autoPresentCorrectionIfNeeded() }
        }
    }

    @ViewBuilder
    private var bigButton: some View {
        switch state {
        case .empty, .completed:
            Button(action: tapNight) {
                buttonShape(
                    emoji: "🌙", title: "おやすみ",
                    subtitle: "タップで入床時刻を記録",
                    colors: [Color.purple, Color(red: 0.36, green: 0.13, blue: 0.71)]
                )
            }
        case .inBed:
            if SleepStateMachine.isAwakeMidSleep(activeSession: activeSession) {
                Button(action: tapBackToSleep) {
                    buttonShape(
                        emoji: "🛏️", title: "再び眠る",
                        subtitle: elapsedSinceWokeUp(),
                        colors: [Color(red: 0.36, green: 0.13, blue: 0.71), Color.purple]
                    )
                }
            } else {
                Button(action: tapMorning) {
                    buttonShape(
                        emoji: "☀️", title: "おはよう",
                        subtitle: "タップで起床時刻を記録",
                        colors: [Color.orange, Color(red: 0.96, green: 0.62, blue: 0.04)]
                    )
                }
            }
        case .correctionPending:
            Button(action: { showCorrectionSheet = true }) {
                buttonShape(
                    emoji: "📝", title: "補正する",
                    subtitle: "入眠/覚醒時刻を確定",
                    colors: [Color(red: 0.96, green: 0.62, blue: 0.04), Color.red]
                )
            }
            .overlay(alignment: .topTrailing) {
                Circle().fill(.red).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 8, y: -8)
            }
        }
    }

    private func buttonShape(
        emoji: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        colors: [Color]
    ) -> some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 48))
            Text(title).font(.title3.bold()).foregroundStyle(.white)
        }
        .frame(width: 180, height: 180)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Circle())
        .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 24, x: 0, y: 8)
        .overlay(alignment: .bottom) {
            Text(subtitle)
                .font(.caption2).foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
                .offset(y: 28)
        }
    }

    private func tapNight() {
        let s = SleepSession(bedInAt: now)
        modelContext.insert(s)
        try? modelContext.save()
    }

    private func tapMorning() {
        closeOpenWakeEventsForMorning()
        guard let s = activeSession else {
            let result = BackfillDetector.detect(now: now, activeSession: nil)
            backfillSuggested = result.suggestedBedInAt ?? now
            showBackfillSheet = true
            return
        }
        s.bedOutAt = now
        s.updatedAt = now
        try? modelContext.save()
        showCorrectionSheet = true
    }

    private func tapWokeUp() {
        guard let s = activeSession else { return }
        let event = WakeEvent(startedAt: now, session: s)
        modelContext.insert(event)
        s.wakeEvents.append(event)
        s.updatedAt = now
        try? modelContext.save()
    }

    private func tapBackToSleep() {
        guard let s = activeSession else { return }
        if let openEvent = s.wakeEvents.first(where: { $0.isOpen }) {
            openEvent.endedAt = now
            openEvent.updatedAt = now
            s.updatedAt = now
            try? modelContext.save()
        }
    }

    /// Closes any open wake events; called from tapMorning before existing logic runs.
    private func closeOpenWakeEventsForMorning() {
        guard let s = activeSession else { return }
        var dirty = false
        for event in s.wakeEvents where event.isOpen {
            event.endedAt = now
            event.updatedAt = now
            dirty = true
        }
        if dirty {
            s.updatedAt = now
            try? modelContext.save()
        }
    }

    private func elapsedSinceWokeUp() -> LocalizedStringKey {
        guard let s = activeSession,
              let openEvent = s.wakeEvents.first(where: { $0.isOpen })
        else { return "" }
        let secs = Int(now.timeIntervalSince(openEvent.startedAt))
        let totalMin = max(0, secs / 60)
        if totalMin < 1 {
            return "wake.elapsed.minutesUnder1"
        }
        if totalMin < 60 {
            return LocalizedStringKey("wake.elapsed.minutes \(totalMin)")
        }
        let h = totalMin / 60
        let m = totalMin % 60
        return LocalizedStringKey("wake.elapsed.hoursMinutes \(h) \(m)")
    }

    private func autoPresentCorrectionIfNeeded() {
        if state == .correctionPending {
            showCorrectionSheet = true
        }
    }

    private func isCompleted(_ s: SleepSession) -> Bool {
        s.bedOutAt != nil && s.asleepAt != nil && s.awakeAt != nil
    }
}

private struct BackfillSheet: View {
    let suggestedBedInAt: Date
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var bedInAt: Date

    init(suggestedBedInAt: Date, onConfirm: @escaping (Date) -> Void) {
        self.suggestedBedInAt = suggestedBedInAt
        self.onConfirm = onConfirm
        self._bedInAt = State(initialValue: suggestedBedInAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("「おやすみ」のタップが見つかりません") {
                    Text("昨夜は何時頃に布団に入りましたか？")
                    DatePicker(
                        "入床時刻",
                        selection: $bedInAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("入床時刻の補完")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") { onConfirm(bedInAt); dismiss() }
                }
            }
        }
    }
}
