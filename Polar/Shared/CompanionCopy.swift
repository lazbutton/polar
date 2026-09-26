import Foundation

enum CompanionCopy {
    static let touchLines = [
        "Je suis là.",
        "Tu peux noter juste un mot.",
        "Rien n'est obligatoire.",
        "À tout à l'heure.",
    ]

    static func greeting(
        at date: Date,
        lastNote: Date?,
        phrasesEnabled: Bool,
        calendar: Calendar = .current
    ) -> String? {
        guard phrasesEnabled else { return nil }
        let hour = calendar.component(.hour, from: date)
        if hour >= 23 || hour < 5 {
            return "Il est tard. Je garde ça pour toi."
        }
        if let lastNote {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastNote),
                to: calendar.startOfDay(for: date)
            ).day ?? 0
            if days >= 3 { return "Content de te revoir." }
        }
        switch hour {
        case 5..<12: return "Bonjour. Comment ça va ?"
        case 12..<18: return "Bon après-midi. Comment ça va ?"
        default: return "Bonsoir. Comment ça va ?"
        }
    }
}
