import SwiftUI
import SwiftData

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepSession.bedInAt, order: .reverse) private var sessions: [SleepSession]

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date?
    @State private var showPDFExport = false

    private let calendar = Calendar.current

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
                ScrollView {
                    let calc = ChartCellCalculator()
                    LazyVStack(spacing: 2) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 56)
                            GeometryReader { geo in
                                let w = geo.size.width / 24
                                HStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text("\(h)")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                            .frame(width: w, alignment: .leading)
                                    }
                                }
                            }.frame(height: 12)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)

                        ForEach(monthDays.reversed(), id: \.self) { day in
                            Button {
                                selectedDay = day
                            } label: {
                                DayRowView(date: day, cells: calc.cells(forDay: day, sessions: sessions))
                                    .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
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
