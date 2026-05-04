import Foundation
import PDFKit
import UIKit

@MainActor
enum PDFExporter {
    static let daysPerPage = 35
    static let cellWidth: CGFloat = 16
    static let cellHeight: CGFloat = 16
    static let labelWidth: CGFloat = 48
    static let notesColumnWidth: CGFloat = 110
    static let pageMargin: CGFloat = 24

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
        let bannerHeight: CGFloat = 14
        let hourLabelHeight: CGFloat = 10
        let chartTop: CGFloat = pageMargin + 60 + bannerHeight + hourLabelHeight
        let chartLeft = pageMargin + labelWidth
        let notesLeft = chartLeft + 24 * cellWidth + 4

        // 午前 / 午後 banner row
        let bannerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.black,
            .paragraphStyle: centeredParagraphStyle()
        ]
        let amRect = CGRect(x: chartLeft, y: chartTop - bannerHeight - hourLabelHeight,
                            width: 12 * cellWidth, height: bannerHeight)
        let pmRect = CGRect(x: chartLeft + 12 * cellWidth, y: chartTop - bannerHeight - hourLabelHeight,
                            width: 12 * cellWidth, height: bannerHeight)
        let notesBannerRect = CGRect(x: notesLeft, y: chartTop - bannerHeight - hourLabelHeight,
                                     width: notesColumnWidth, height: bannerHeight)
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(rect: amRect).fill()
        UIBezierPath(rect: pmRect).fill()
        UIBezierPath(rect: notesBannerRect).fill()
        UIColor.black.setStroke()
        for r in [amRect, pmRect, notesBannerRect] {
            let p = UIBezierPath(rect: r); p.lineWidth = 0.5; p.stroke()
        }
        ("午前" as NSString).draw(in: amRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)
        ("午後" as NSString).draw(in: pmRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)
        ("備考欄" as NSString).draw(in: notesBannerRect.insetBy(dx: 0, dy: 1), withAttributes: bannerAttrs)

        // Hour numbers row: 0-11 / 0-11
        let hourFont = UIFont.systemFont(ofSize: 7)
        let hourAttrs: [NSAttributedString.Key: Any] = [
            .font: hourFont,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: centeredParagraphStyle()
        ]
        for h in 0..<12 {
            let amRect = CGRect(x: chartLeft + CGFloat(h) * cellWidth,
                                y: chartTop - hourLabelHeight,
                                width: cellWidth, height: hourLabelHeight)
            let pmRect = CGRect(x: chartLeft + CGFloat(h + 12) * cellWidth,
                                y: chartTop - hourLabelHeight,
                                width: cellWidth, height: hourLabelHeight)
            ("\(h)" as NSString).draw(in: amRect, withAttributes: hourAttrs)
            ("\(h)" as NSString).draw(in: pmRect, withAttributes: hourAttrs)
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        let notesAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.darkGray
        ]

        for (idx, day) in days.enumerated() {
            let y = chartTop + CGFloat(idx) * cellHeight
            let label = formatter.string(from: day) as NSString
            label.draw(at: CGPoint(x: pageMargin, y: y + 2), withAttributes: labelAttrs)

            let cells = calc.cells(forDay: day, sessions: sessions)
            for (h, cell) in cells.enumerated() {
                let x = chartLeft + CGFloat(h) * cellWidth
                let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                drawCell(rect: cellRect, cell: cell)
            }

            // Notes cell border (per-row, matches drawCell line weight)
            let notesCellRect = CGRect(
                x: notesLeft, y: y,
                width: notesColumnWidth, height: cellHeight
            )
            UIColor.black.setStroke()
            let notesCellBorder = UIBezierPath(rect: notesCellRect)
            notesCellBorder.lineWidth = 0.3
            notesCellBorder.stroke()

            let notes = calc.notes(forDay: day, sessions: sessions)
            if !notes.isEmpty {
                let notesRect = CGRect(
                    x: notesLeft,
                    y: y + 1,
                    width: notesColumnWidth,
                    height: cellHeight - 1
                )
                (notes as NSString).draw(in: notesRect, withAttributes: notesAttrs)
            }
        }

        // AM/PM separator at hour 12
        let midX = chartLeft + 12 * cellWidth
        let separator = UIBezierPath()
        separator.move(to: CGPoint(x: midX, y: chartTop))
        separator.addLine(to: CGPoint(x: midX, y: chartTop + CGFloat(days.count) * cellHeight))
        UIColor.black.setStroke()
        separator.lineWidth = 1.5
        separator.stroke()
    }

    private static func centeredParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return p
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

}
