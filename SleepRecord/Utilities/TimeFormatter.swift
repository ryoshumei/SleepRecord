import Foundation

enum TimeFormatter {
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dateLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        // Compact form so the column fits both ja "5/3 日" and en "5/3 Sun"
        // on a single line at 48pt. With parens "(Sun)" it wraps in EN.
        f.dateFormat = "M/d E"
        return f
    }()

    static let monthLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        // Locale-driven: ja → "2026年5月", en → "May 2026"
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f
    }()

    static func snapTo5Min(_ date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let minute = comps.minute else { return date }
        let snapped = (minute / 5) * 5
        var newComps = comps
        newComps.minute = snapped
        newComps.second = 0
        return calendar.date(from: newComps) ?? date
    }
}
