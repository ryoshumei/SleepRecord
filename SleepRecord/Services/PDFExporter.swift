import Foundation
import PDFKit
import UIKit

@MainActor
enum PDFExporter {
    static let daysPerPage = 35
    static let cellWidth: CGFloat = 18
    static let cellHeight: CGFloat = 14
    static let labelWidth: CGFloat = 56
    static let pageMargin: CGFloat = 36

    nonisolated static func pages(totalDays: Int) -> Int {
        max(1, Int(ceil(Double(totalDays) / Double(daysPerPage))))
    }

    static func makePDF(
        sessions: [SleepSession],
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Data {
        var cal = calendar
        cal.timeZone = timeZone

        let allDays = enumerateDays(start: startDate, end: endDate, calendar: cal)
        let calc = ChartCellCalculator(calendar: cal, timeZone: timeZone)

        let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            let chunks = stride(from: 0, to: allDays.count, by: daysPerPage).map {
                Array(allDays[$0..<min($0 + daysPerPage, allDays.count)])
            }

            for (idx, chunk) in chunks.enumerated() {
                ctx.beginPage()
                drawHeader(
                    rect: pageRect,
                    startDate: startDate,
                    endDate: endDate,
                    pageNum: idx + 1,
                    totalPages: chunks.count
                )
                drawChart(rect: pageRect, days: chunk, sessions: sessions, calc: calc, calendar: cal)
            }

            let notes = sessions.compactMap { s -> (Date, String)? in
                guard !s.notes.isEmpty else { return nil }
                return (s.bedInAt, s.notes)
            }.sorted(by: { $0.0 < $1.0 })

            if !notes.isEmpty {
                ctx.beginPage()
                drawHeader(
                    rect: pageRect,
                    startDate: startDate,
                    endDate: endDate,
                    pageNum: chunks.count + 1,
                    totalPages: chunks.count + 1
                )
                drawNotes(rect: pageRect, notes: notes, calendar: cal)
            }
        }
    }

    private static func enumerateDays(start: Date, end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private static func drawHeader(
        rect: CGRect,
        startDate: Date,
        endDate: Date,
        pageNum: Int,
        totalPages: Int
    ) {
        let title = "睡眠リズム表" as NSString
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: pageMargin, y: pageMargin), withAttributes: titleAttrs)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let range = "期間: \(formatter.string(from: startDate)) 〜 \(formatter.string(from: endDate))" as NSString
        let rangeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        range.draw(at: CGPoint(x: pageMargin, y: pageMargin + 24), withAttributes: rangeAttrs)

        let pageStr = "\(pageNum) / \(totalPages)" as NSString
        let pageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let size = pageStr.size(withAttributes: pageAttrs)
        pageStr.draw(
            at: CGPoint(x: rect.width - pageMargin - size.width, y: pageMargin + 4),
            withAttributes: pageAttrs
        )
    }

    private static func drawChart(
        rect: CGRect,
        days: [Date],
        sessions: [SleepSession],
        calc: ChartCellCalculator,
        calendar: Calendar
    ) {
        let chartTop: CGFloat = pageMargin + 60
        let chartLeft = pageMargin + labelWidth

        let hourFont = UIFont.systemFont(ofSize: 7)
        for h in 0..<24 {
            let str = "\(h)" as NSString
            str.draw(
                at: CGPoint(x: chartLeft + CGFloat(h) * cellWidth + 1, y: chartTop - 12),
                withAttributes: [.font: hourFont, .foregroundColor: UIColor.darkGray]
            )
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]

        for (idx, day) in days.enumerated() {
            let y = chartTop + CGFloat(idx) * cellHeight
            let label = formatter.string(from: day) as NSString
            label.draw(at: CGPoint(x: pageMargin, y: y + 1), withAttributes: labelAttrs)

            let cells = calc.cells(forDay: day, sessions: sessions)
            for (h, cell) in cells.enumerated() {
                let x = chartLeft + CGFloat(h) * cellWidth
                let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                drawCell(rect: cellRect, cell: cell)
            }
        }

        let midX = chartLeft + 12 * cellWidth
        let separator = UIBezierPath()
        separator.move(to: CGPoint(x: midX, y: chartTop))
        separator.addLine(to: CGPoint(x: midX, y: chartTop + CGFloat(days.count) * cellHeight))
        UIColor.black.setStroke()
        separator.lineWidth = 1.5
        separator.stroke()
    }

    private static func drawCell(rect: CGRect, cell: ChartCell) {
        UIColor.black.setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 0.3
        border.stroke()

        if cell.inBed {
            let bot = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)
            UIColor(red: 0.9, green: 0.22, blue: 0.27, alpha: 1).setFill()
            UIBezierPath(rect: bot).fill()
        }

        if cell.asleep {
            let top = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2)
            UIGraphicsGetCurrentContext()?.saveGState()
            UIBezierPath(rect: top).addClip()
            let spacing: CGFloat = 2.5
            var x = top.minX - top.height
            while x < top.maxX + top.height {
                let line = UIBezierPath()
                line.move(to: CGPoint(x: x, y: top.maxY))
                line.addLine(to: CGPoint(x: x + top.height, y: top.minY))
                UIColor.black.setStroke()
                line.lineWidth = 0.6
                line.stroke()
                x += spacing
            }
            UIGraphicsGetCurrentContext()?.restoreGState()
        }
    }

    private static func drawNotes(rect: CGRect, notes: [(Date, String)], calendar: Calendar) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        ("備考一覧" as NSString).draw(
            at: CGPoint(x: pageMargin, y: pageMargin + 50),
            withAttributes: titleAttrs
        )

        var y: CGFloat = pageMargin + 80
        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        for (date, text) in notes {
            let datePrefix = "\(formatter.string(from: date))  " as NSString
            datePrefix.draw(at: CGPoint(x: pageMargin, y: y), withAttributes: dateAttrs)
            let dateWidth = datePrefix.size(withAttributes: dateAttrs).width
            let body = text as NSString
            let bodyRect = CGRect(
                x: pageMargin + dateWidth,
                y: y,
                width: rect.width - 2 * pageMargin - dateWidth,
                height: 60
            )
            body.draw(in: bodyRect, withAttributes: lineAttrs)
            y += 32
            if y > rect.height - pageMargin { break }
        }
    }
}
