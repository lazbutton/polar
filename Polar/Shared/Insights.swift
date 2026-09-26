import Foundation

enum Insights {
    static func lines(
        logs: [DayLog],
        moments: [Moment],
        rules: [AlertRule],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [String] {
        let logs = logs.filter { interval.contains($0.day) }
        let moments = moments.filter { interval.contains($0.createdAt) }
        var lines: [String] = []

        if let threshold = rules.first(where: { $0.kind == .shortSleep })?.threshold {
            let short = logs.filter { ($0.resolvedSleepHours ?? .greatestFiniteMagnitude) < threshold }.count
            if short > 0 {
                lines.append("\(short) nuit\(short > 1 ? "s" : "") courte\(short > 1 ? "s" : "") cette période")
            }
        }

        let noted = logs.filter { $0.resolvedSleepHours != nil }.count
        if noted > 0 {
            lines.append("Sommeil noté \(noted) nuit\(noted > 1 ? "s" : "")")
        }

        let daysWithMeds = Set(logs.filter { log in
            log.intakes?.isEmpty == false
        }.map { calendar.startOfDay(for: $0.day) })
        if !daysWithMeds.isEmpty {
            let takenDays = logs.filter { log in
                let intakes = log.intakes ?? []
                return !intakes.isEmpty && intakes.allSatisfy(\.taken)
            }.count
            let scheduled = logs.filter { ($0.intakes ?? []).isEmpty == false }.count
            lines.append("Traitement pris \(takenDays) jour\(takenDays > 1 ? "s" : "") sur \(scheduled)")
        }

        let doseChanges = logs.reduce(0) { count, log in
            count + (log.intakes ?? []).filter { $0.doseChange?.isEmpty == false }.count
        }
        if doseChanges > 0 {
            lines.append("\(doseChanges) changement\(doseChanges > 1 ? "s" : "") de dose")
        }

        if !moments.isEmpty {
            lines.append("\(moments.count) moment\(moments.count > 1 ? "s" : "") noté\(moments.count > 1 ? "s" : "")")
        }
        return lines
    }

    /// Une ligne sous la courbe d'humeur.
    static func moodLine(_ logs: [DayLog]) -> String {
        let two = Instability.twoPoleDays(logs).count
        if two > 0 { return "\(two) jour\(two > 1 ? "s" : "") à deux pôles" }
        let high = logs.filter { $0.elevated >= 2 }.count
        if high > 0 { return "\(high) jour\(high > 1 ? "s" : "") d'humeur haute" }
        let low = logs.filter { $0.depressed >= 2 }.count
        if low > 0 { return "\(low) jour\(low > 1 ? "s" : "") d'humeur basse" }
        return "Humeur haute au-dessus, basse en dessous"
    }

    /// Une ligne sous la courbe de sommeil.
    static func sleepLine(_ logs: [DayLog], calendar: Calendar = .current) -> String {
        let sorted = logs.sorted { $0.day < $1.day }
        var later = 0
        for (index, log) in sorted.enumerated() {
            guard let night = log.resolvedSleepNight(calendar: calendar) else { continue }
            let previous = sorted.prefix(index).compactMap { $0.resolvedSleepNight(calendar: calendar) }
            if let shift = SleepMetrics.midpointShift(tonight: night, previous: previous, calendar: calendar), shift >= 30 {
                later += 1
            }
        }
        if later > 0 { return "\(later) nuit\(later > 1 ? "s" : "") plus tardive\(later > 1 ? "s" : "")" }
        let short = logs.filter { ($0.resolvedSleepHours ?? 99) < 6 }.count
        if short > 0 { return "\(short) nuit\(short > 1 ? "s" : "") courte\(short > 1 ? "s" : "")" }
        return "Coucher et lever, nuit par nuit"
    }

    static func frequentEmotions(_ moments: [Moment], limit: Int = 5) -> [(label: String, count: Int, hours: [Int])] {
        var buckets: [String: (count: Int, hours: [Int])] = [:]
        let calendar = Calendar.current
        for moment in moments {
            guard let key = moment.emotionKey else { continue }
            let label = moment.emotionLabel
            var entry = buckets[label] ?? (0, [])
            entry.count += 1
            if key == moment.emotionKey {
                entry.hours.append(calendar.component(.hour, from: moment.createdAt))
            }
            buckets[label] = entry
        }
        return buckets
            .map { (label: $0.key, count: $0.value.count, hours: $0.value.hours) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }
}
