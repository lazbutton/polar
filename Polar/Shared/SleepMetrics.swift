import Foundation

/// Une nuit de sommeil, du coucher au lever.
struct SleepNight: Equatable {
    let bedtime: Date
    let wake: Date

    var duration: TimeInterval { wake.timeIntervalSince(bedtime) }

    /// Ramène une nuit au jour logique à partir des heures affichées.
    /// Le lever est le matin de ce jour. Si l'heure de coucher est plus tard
    /// que l'heure de lever (23 h → 7 h), le coucher est la veille au soir.
    /// Sinon les deux restent le même matin (4 h → 11 h 30 = 7 h 30).
    static func anchored(bedtime: Date, wake: Date, on logicalDay: Date, calendar: Calendar = .current) -> SleepNight? {
        let bedClock = calendar.dateComponents([.hour, .minute], from: bedtime)
        let wakeClock = calendar.dateComponents([.hour, .minute], from: wake)
        guard
            let bedHour = bedClock.hour, let bedMinute = bedClock.minute,
            let wakeHour = wakeClock.hour, let wakeMinute = wakeClock.minute,
            let wakeDate = calendar.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: logicalDay),
            var bedDate = calendar.date(bySettingHour: bedHour, minute: bedMinute, second: 0, of: logicalDay)
        else { return nil }
        if bedDate > wakeDate {
            guard let previousEvening = calendar.date(byAdding: .day, value: -1, to: bedDate) else { return nil }
            bedDate = previousEvening
        }
        return SleepNight(bedtime: bedDate, wake: wakeDate)
    }

    /// Milieu du sommeil en minutes après 18 h, pour éviter le passage de minuit.
    func midpointMinutes(calendar: Calendar = .current) -> Double {
        let mid = bedtime.addingTimeInterval(duration / 2)
        let components = calendar.dateComponents([.hour, .minute], from: mid)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        return (minutes - 18 * 60 + 24 * 60).truncatingRemainder(dividingBy: 24 * 60)
    }
}

enum SleepMetrics {
    /// Décalage du milieu du sommeil par rapport à la médiane des 28 nuits précédentes.
    /// Positif : plus tard que d'habitude. Négatif : plus tôt. nil sous 10 nuits de référence.
    static func midpointShift(tonight: SleepNight, previous: [SleepNight], calendar: Calendar = .current) -> Double? {
        let reference = previous.suffix(28).map { $0.midpointMinutes(calendar: calendar) }.sorted()
        guard reference.count >= 10 else { return nil }
        return tonight.midpointMinutes(calendar: calendar) - median(reference)
    }

    /// Écarts-types sur les 7 dernières nuits, en minutes : durée et heure de lever.
    /// nil sous 5 nuits.
    static func variability(_ nights: [SleepNight], calendar: Calendar = .current) -> (duration: Double, wake: Double)? {
        let last = Array(nights.suffix(7))
        guard last.count >= 5 else { return nil }
        let durations = last.map { $0.duration / 60 }
        let wakes = last.map { night -> Double in
            let components = calendar.dateComponents([.hour, .minute], from: night.wake)
            return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        }
        return (standardDeviation(durations), standardDeviation(wakes))
    }

    /// Écart-type d'un échantillon (n − 1).
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        return variance.squareRoot()
    }

    /// Médiane d'un tableau déjà trié.
    static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }
}
