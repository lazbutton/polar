import Foundation

/// Faits factuels pour Préparer ma séance et le rapport. Aucun jugement, aucune tendance.
enum SessionFacts {
    /// Dernière séance faite. Les séances 0.3 priment ; les bilans 0.2 restent en secours.
    static func lastSessionDate(logs: [DayLog], sessions: [TherapySession] = []) -> Date? {
        let fromSessions = sessions.filter(\.done).map(\.date).max()
        let fromLogs = logs.filter(\.therapySession).map(\.day).max()
        return [fromSessions, fromLogs].compactMap { $0 }.max()
    }

    static func nextSession(in sessions: [TherapySession]) -> TherapySession? {
        sessions.filter { !$0.done }.sorted { $0.date < $1.date }.first
    }

    static func lines(
        logs: [DayLog],
        moments: [Moment],
        surveys: [SurveyResponse],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [String] {
        let logs = logs.filter { interval.contains($0.day) }
        var lines: [String] = []

        let nights = logs.compactMap { $0.resolvedSleepHours }
        if !nights.isEmpty {
            let mean = nights.reduce(0, +) / Double(nights.count)
            lines.append("Sommeil moyen \(sleep(mean)) sur \(nights.count) nuits")
        }

        let sleepNights = logs.compactMap { $0.resolvedSleepNight(calendar: calendar) }
        if let variability = SleepMetrics.variability(sleepNights, calendar: calendar) {
            lines.append("Variabilité du lever ± \(Int(variability.wake.rounded())) min")
        }

        let elevatedDays = logs.filter { $0.elevated >= 1 }.count
        let depressedDays = logs.filter { $0.depressed >= 1 }.count
        let twoPoleDays = Instability.twoPoleDays(logs).count
        if elevatedDays > 0 { lines.append("\(elevatedDays) jours avec humeur haute") }
        if depressedDays > 0 { lines.append("\(depressedDays) jours avec humeur basse") }
        if twoPoleDays > 0 { lines.append("\(twoPoleDays) jours à deux pôles") }

        let energies = logs.compactMap { $0.energy }
        if !energies.isEmpty {
            let mean = Double(energies.reduce(0, +)) / Double(energies.count)
            lines.append("Énergie moyenne \(String(format: "%+.1f", mean))")
        }

        let scheduled = logs.filter { ($0.intakes ?? []).isEmpty == false }.count
        if scheduled > 0 {
            let taken = logs.filter { log in
                let intakes = log.intakes ?? []
                return !intakes.isEmpty && intakes.allSatisfy(\.taken)
            }.count
            lines.append("Traitement pris \(taken) jours sur \(scheduled)")
        }

        let doseChanges = logs.reduce(0) { $0 + (($1.intakes ?? []).filter { $0.doseChange?.isEmpty == false }.count) }
        if doseChanges > 0 {
            lines.append("\(doseChanges) changement\(doseChanges > 1 ? "s" : "") de dose")
        }

        return lines
    }

    private static func sleep(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    /// Derniers scores de chaque questionnaire sur la période, avec le précédent s'il existe.
    static func surveyLines(surveys: [SurveyResponse]) -> [String] {
        var lines: [String] = []
        for questionnaire in Questionnaire.all {
            let matching = surveys.filter { $0.instrument == questionnaire.id }.sorted { $0.date > $1.date }
            guard let latest = matching.first else { continue }
            var line = "\(questionnaire.title) : \(latest.score) sur \(questionnaire.maxScore)"
            if matching.count > 1 {
                line += " (avant : \(matching[1].score))"
            }
            lines.append(line)
        }
        return lines
    }
}
