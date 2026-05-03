import Foundation

enum TimeFormatter {
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dateLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (E)"
        return f
    }()

    static let monthLabel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
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
