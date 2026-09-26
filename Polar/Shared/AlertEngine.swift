import Foundation

struct AlertHit: Identifiable, Equatable {
    var id: UUID { rule.id }
    var rule: AlertRule
    var detail: String
    var pole: Pole?
    var stage: Int

    static func == (lhs: AlertHit, rhs: AlertHit) -> Bool {
        lhs.rule == rhs.rule && lhs.detail == rhs.detail
    }
}

/// Évalue les signaux de 10.2 sur des faits. Aucun calcul de risque : seulement des conditions
/// fixées avec ta psy. Tous les signaux sont désactivés tant qu'ils ne sont pas ajoutés.
enum AlertEngine {
    static func hits(
        rules: [AlertRule],
        logs: [DayLog],
        plan: CarePlan? = nil,
        surveys: [SurveyResponse] = [],
        today: Date = .now,
        startHour: Int = 4,
        calendar: Calendar = .current
    ) -> [AlertHit] {
        let today = today.logicalDay(startHour: startHour, calendar: calendar)
        return rules.filter(\.isOn).compactMap { rule in
            evaluate(rule, logs: logs, plan: plan, surveys: surveys, today: today, calendar: calendar)
        }
    }

    private static func evaluate(
        _ rule: AlertRule,
        logs: [DayLog],
        plan: CarePlan?,
        surveys: [SurveyResponse],
        today: Date,
        calendar: Calendar
    ) -> AlertHit? {
        switch rule.kind {
        case .shortSleep:
            return shortSleep(rule, logs: logs, today: today, calendar: calendar)
        case .sleepLate:
            return sleepShift(rule, logs: logs, today: today, calendar: calendar, later: true)
        case .sleepEarly:
            return sleepShift(rule, logs: logs, today: today, calendar: calendar, later: false)
        case .sleepIrregular:
            return sleepIrregular(rule, logs: logs, today: today, calendar: calendar)
        case .energyHigh:
            return streak(rule, logs: logs, today: today, calendar: calendar) {
                ($0.energy ?? 0) >= Int(rule.threshold.rounded())
            } detail: { "Énergie haute pendant \(rule.span) jours" }
        case .elevated:
            return streak(rule, logs: logs, today: today, calendar: calendar) {
                $0.elevated >= Int(rule.threshold.rounded())
            } detail: { "\(rule.kind.label) \(levelName(Int(rule.threshold.rounded()))) pendant \(rule.span) jours" }
        case .depressed:
            return streak(rule, logs: logs, today: today, calendar: calendar) {
                $0.depressed >= Int(rule.threshold.rounded())
            } detail: { "\(rule.kind.label) \(levelName(Int(rule.threshold.rounded()))) pendant \(rule.span) jours" }
        case .twoPole:
            return streak(rule, logs: logs, today: today, calendar: calendar) {
                Instability.isTwoPoleDay($0, threshold: Int(rule.threshold.rounded()))
            } detail: { "Deux pôles le même jour pendant \(rule.span) jours" }
        case .signs:
            return signs(rule, logs: logs, plan: plan, today: today, calendar: calendar)
        case .medMissed:
            return medMissed(rule, logs: logs, today: today, calendar: calendar)
        case .phq9:
            return survey(rule, surveys: surveys, instrument: "phq9", label: "PHQ-9")
        case .asrm:
            return survey(rule, surveys: surveys, instrument: "asrm", label: "ASRM")
        }
    }

    // MARK: - Sommeil

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
        return hit(rule, "Sommeil sous \(formatHours(rule.threshold)) pendant \(nights) nuits")
    }

    private static func sleepShift(_ rule: AlertRule, logs: [DayLog], today: Date, calendar: Calendar, later: Bool) -> AlertHit? {
        let span = max(rule.span, 1)
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let nights = nights(upTo: day, logs: logs, calendar: calendar)
            guard let tonight = nights.last,
                  let shift = SleepMetrics.midpointShift(tonight: tonight, previous: Array(nights.dropLast()), calendar: calendar)
            else { return nil }
            if later {
                guard shift > rule.threshold else { return nil }
            } else {
                guard shift < -rule.threshold else { return nil }
            }
        }
        let word = later ? "plus tard" : "plus tôt"
        return hit(rule, "Sommeil \(word) que d'habitude, \(span) nuits")
    }

    private static func sleepIrregular(_ rule: AlertRule, logs: [DayLog], today: Date, calendar: Calendar) -> AlertHit? {
        let nights = nights(upTo: today, logs: logs, calendar: calendar)
        guard let variability = SleepMetrics.variability(nights, calendar: calendar) else { return nil }
        guard variability.wake > rule.threshold else { return nil }
        return hit(rule, "Lever irrégulier, ± \(Int(variability.wake.rounded())) min sur 7 nuits")
    }

    /// Nuits (coucher + lever) jusqu'à `day` inclus, triées par jour.
    private static func nights(upTo day: Date, logs: [DayLog], calendar: Calendar) -> [SleepNight] {
        logs
            .filter { $0.day <= day.addingTimeInterval(1) }
            .compactMap { log -> (Date, SleepNight)? in
                guard let bedtime = log.bedtime, let wake = log.wakeTime, wake > bedtime else { return nil }
                return (log.day, SleepNight(bedtime: bedtime, wake: wake))
            }
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }
    }

    // MARK: - Humeur, énergie, deux pôles

    private static func streak(
        _ rule: AlertRule,
        logs: [DayLog],
        today: Date,
        calendar: Calendar,
        matches: (DayLog) -> Bool,
        detail: () -> String
    ) -> AlertHit? {
        let span = max(rule.span, 1)
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let log = logs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }),
                  matches(log) else { return nil }
        }
        return hit(rule, detail())
    }

    // MARK: - Signes précurseurs

    private static func signs(_ rule: AlertRule, logs: [DayLog], plan: CarePlan?, today: Date, calendar: Calendar) -> AlertHit? {
        guard let plan else { return nil }
        let span = max(rule.span, 1)
        let poleFor = Dictionary(uniqueKeysWithValues: plan.signs.map { ($0.id, $0.pole) })
        var seen = Set<UUID>()
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let log = logs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) else { continue }
            for id in log.signsSeen where poleFor[id] ?? nil == rule.pole {
                seen.insert(id)
            }
        }
        guard seen.count >= Int(rule.threshold.rounded()) else { return nil }
        return hit(rule, "\(seen.count) signes remarqués sur \(span) jours")
    }

    // MARK: - Traitement

    private static func medMissed(_ rule: AlertRule, logs: [DayLog], today: Date, calendar: Calendar) -> AlertHit? {
        let span = max(rule.span, 1)
        var missed = 0
        for offset in 0..<span {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let log = logs.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) else { continue }
            missed += (log.intakes ?? []).filter { !$0.taken }.count
        }
        let need = max(Int(rule.threshold.rounded()), 1)
        guard missed >= need else { return nil }
        return hit(rule, "Traitement manqué \(missed) fois sur \(span) jours")
    }

    // MARK: - Questionnaires

    private static func survey(_ rule: AlertRule, surveys: [SurveyResponse], instrument: String, label: String) -> AlertHit? {
        guard let latest = surveys.filter({ $0.instrument == instrument }).max(by: { $0.date < $1.date }) else { return nil }
        guard Double(latest.score) >= rule.threshold else { return nil }
        return hit(rule, "\(label) à \(latest.score)")
    }

    // MARK: - Helpers

    private static func hit(_ rule: AlertRule, _ detail: String) -> AlertHit {
        AlertHit(rule: rule, detail: detail, pole: rule.pole, stage: rule.stage)
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
