import SwiftUI
import SwiftData

struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SleepSession.bedInAt) private var sessions: [SleepSession]

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var pdfData: Data?
    @State private var isGenerating = false

    init() {
        let r = DateRange.defaultPDFRange()
        self._startDate = State(initialValue: r.start)
        self._endDate = State(initialValue: r.end)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("出力期間") {
                        DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                        Button("この期間でプレビュー") { generate() }
                    }
                }
                .frame(maxHeight: 240)

                if let data = pdfData {
                    PDFPreviewView(data: data)
                        .background(Color(.systemGroupedBackground))
                    HStack(spacing: 12) {
                        ShareLink(item: pdfFile(data: data)) {
                            Label("共有 / 保存", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button(action: { presentPrint(data: data) }) {
                            Label("印刷", systemImage: "printer")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                } else {
                    Spacer()
                    if isGenerating {
                        ProgressView("生成中…")
                    } else {
                        Text("「プレビュー」を押して PDF を生成してください")
                            .foregroundStyle(.secondary).padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("PDF出力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
            .task { generate() }
        }
    }

    @MainActor
    private func generate() {
        isGenerating = true
        let data = PDFExporter.makePDF(
            sessions: Array(sessions),
            startDate: startDate,
            endDate: endDate
        )
        pdfData = data
        isGenerating = false
    }

    private func pdfFile(data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleep-rhythm-\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }

    private func presentPrint(data: Data) {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = String(localized: "pdf.title", defaultValue: "睡眠リズム表")
        let pc = UIPrintInteractionController.shared
        pc.printInfo = info
        pc.printingItem = data
        pc.present(animated: true) { _, _, _ in }
    }
}
