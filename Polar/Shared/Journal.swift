import Foundation

enum Journal {
    static func moments(
        _ moments: [Moment],
        on date: Date,
        startHour: Int,
        calendar: Calendar = .current
    ) -> [Moment] {
        let day = date.logicalDay(startHour: startHour, calendar: calendar)
        return moments
            .filter { $0.createdAt.logicalDay(startHour: startHour, calendar: calendar) == day }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func recentEmotionKeys(from moments: [Moment], limit: Int = 8) -> [String] {
        var seen: [String] = []
        let preferred = ["anxiete", "calme", "tristesse", "stress", "joie", "epuisement", "irritation", "soulagement"]
        for moment in moments.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard let key = moment.emotionKey, EmotionCatalog.emotion(for: key) != nil, !seen.contains(key) else { continue }
            seen.append(key)
            if seen.count == limit { return seen }
        }
        for key in preferred where !seen.contains(key) {
            seen.append(key)
            if seen.count == limit { break }
        }
        return seen
    }
}
