import Foundation

struct AlertHit: Identifiable, Equatable {
    var id: UUID { rule.id }
    var rule: AlertRule
    var detail: String
}

enum AlertEngine {
    static func hits(
        rules: [AlertRule],
        logs: [DayLog],
        today: Date = .now,
        startHour: Int = 4,
        calendar: Calendar = .current
    ) -> [AlertHit] {
        let today = today.logicalDay(startHour: startHour, calendar: calendar)
        return rules.compactMap { rule in
            switch rule.kind {
            case .shortSleep:
                return shortSleep(rule, logs: logs, today: today, calendar: calendar)
            case .elevated:
                return streak(rule, logs: logs, today: today, calendar: calendar) { $0.elevated >= Int(rule.threshold.rounded()) }
            case .depressed:
                return streak(rule, logs: logs, today: today, calendar: calendar) { $0.depressed >= Int(rule.threshold.rounded()) }
            }
        }
    }

    private static func shortSleep(_ rule: AlertRule, logs: [DayLog], today: Date, calendar: Calendar) -> AlertHit? {
        let span = max(rule.span, 1)
        var nights = 0
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let log = logs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }),
                  let hours = log.sleepHours else { return nil }
            guard hours < rule.threshold else { return nil }
            nights += 1
        }
        let hours = formatHours(rule.threshold)
        return AlertHit(rule: rule, detail: "Sommeil sous \(hours) pendant \(nights) nuits")
    }

    private static func streak(
        _ rule: AlertRule,
        logs: [DayLog],
        today: Date,
        calendar: Calendar,
        matches: (DayLog) -> Bool
    ) -> AlertHit? {
        let span = max(rule.span, 1)
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let log = logs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }),
                  matches(log) else { return nil }
        }
        let level = levelName(Int(rule.threshold.rounded()))
        return AlertHit(rule: rule, detail: "\(rule.kind.label) \(level) pendant \(span) jours")
    }

    private static func levelName(_ level: Int) -> String {
        ["aucun", "léger", "modéré", "sévère"][min(max(level, 0), 3)]
    }

    private static func formatHours(_ hours: Double) -> String {
        let whole = Int(hours)
        let minutes = Int((hours - Double(whole)) * 60)
        if minutes == 0 { return "\(whole) h" }
        return "\(whole) h \(minutes)"
    }
}
