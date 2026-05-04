import SwiftUI
import SwiftData

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepSession.bedInAt, order: .reverse) private var sessions: [SleepSession]

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?
    @State private var showPDFExport = false

    private let calendar = Calendar.current
    private let dateLabelWidth: CGFloat = 48
    private let notesWidth: CGFloat = 80

    private var chartHeader: some View {
        VStack(spacing: 0) {
            // 午前 / 午後 banner
            HStack(spacing: 0) {
                Color.clear.frame(width: dateLabelWidth + 4)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Text("午前")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: geo.size.width / 2, height: 16)
                            .background(Color(white: 0.92))
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
                        Text("午後")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: geo.size.width / 2, height: 16)
                            .background(Color(white: 0.92))
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
                    }
                }
                .frame(height: 16)
                Text("備考欄")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: notesWidth, height: 16)
                    .padding(.leading, 4)
                    .background(Color(white: 0.92))
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
            }
            // Hour numbers: 0-11 / 0-11
            HStack(spacing: 0) {
                Color.clear.frame(width: dateLabelWidth + 4)
                GeometryReader { geo in
                    let w = geo.size.width / 24
                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { h in
                            Text("\(h)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: w, alignment: .center)
                        }
                        ForEach(0..<12, id: \.self) { h in
                            Text("\(h)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: w, alignment: .center)
                        }
                    }
                }
                .frame(height: 12)
                Color.clear.frame(width: notesWidth)
            }
        }
    }

    var monthDays: [Date] {
        let start = displayedMonth
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else { return [] }
        return DateRange.enumerate(
            start: start,
            end: calendar.date(byAdding: .day, value: -1, to: end) ?? start
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        let calc = ChartCellCalculator()
                        LazyVStack(spacing: 0) {
                            chartHeader
                                .padding(.horizontal, 8)
                                .padding(.top, 4)

                            ForEach(monthDays, id: \.self) { day in
                                Button {
                                    selectedDay = day
                                } label: {
                                    DayRowView(
                                        date: day,
                                        cells: calc.cells(forDay: day, sessions: sessions),
                                        notes: calc.notes(forDay: day, sessions: sessions),
                                        dateLabelWidth: dateLabelWidth,
                                        notesWidth: notesWidth,
                                        rowHeight: 24
                                    )
                                    .padding(.horizontal, 8)
                                }
                                .buttonStyle(.plain)
                                .id(day)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .onAppear {
                        // Scroll to today (or last day of month if today isn't in view) so
                        // the user lands on the most recent date without manual scrolling.
                        let target = monthDays.last(where: { $0 <= .now }) ?? monthDays.last
                        if let target {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation { proxy.scrollTo(target, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("チャート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPDFExport = true } label: {
                        Image(systemName: "doc.text")
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedDay.map { DayWrapper(date: $0) } },
                set: { selectedDay = $0?.date }
            )) { wrapped in
                DayEditSheet(date: wrapped.date)
            }
            .sheet(isPresented: $showPDFExport) {
                PDFExportView()
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(displayedMonth, formatter: TimeFormatter.monthLabel).font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: d)
        }
    }
}

private struct DayWrapper: Identifiable {
    let date: Date
    var id: Date { date }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
