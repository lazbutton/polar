import Foundation

enum Instability {
    /// Moyenne des écarts absolus entre jours consécutifs ; les jours manquants coupent la paire.
    /// nil sous 7 paires.
    static func meanAbsoluteSuccessiveDifference(_ values: [Double?]) -> Double? {
        var diffs: [Double] = []
        for (a, b) in zip(values, values.dropFirst()) {
            if let a, let b { diffs.append(abs(b - a)) }
        }
        guard diffs.count >= 7 else { return nil }
        return diffs.reduce(0, +) / Double(diffs.count)
    }

    /// Humeur du jour sur un axe : de -3 (basse) à +3 (haute).
    static func moodAxis(_ log: DayLog) -> Double { Double(log.elevated - log.depressed) }

    /// Un jour à deux pôles : humeur haute et humeur basse toutes deux au-dessus du seuil.
    static func isTwoPoleDay(_ log: DayLog, threshold: Int = 1) -> Bool {
        log.elevated >= threshold && log.depressed >= threshold
    }

    /// Nombre de jours à deux pôles sur une série.
    static func twoPoleDays(_ logs: [DayLog], threshold: Int = 1) -> [DayLog] {
        logs.filter { isTwoPoleDay($0, threshold: threshold) }
    }
}
