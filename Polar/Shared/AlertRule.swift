import Foundation

/// Un signal de 10.2 : une condition factuelle fixée avec ta psy, avec son palier de plan.
struct AlertRule: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case shortSleep       // sommeil < X h
        case sleepEarly       // milieu du sommeil plus tôt que d'habitude
        case sleepLate        // milieu du sommeil plus tard que d'habitude
        case sleepIrregular   // variabilité du lever hors fourchette
        case energyHigh       // énergie ≥ +X
        case elevated         // humeur haute ≥ X
        case depressed        // humeur basse ≥ X
        case twoPole          // haute et basse ≥ X le même jour
        case signs            // au moins X signes d'un même pôle
        case medMissed        // prises manquées
        case phq9             // score PHQ-9 ≥ X
        case asrm             // score ASRM ≥ X

        var id: String { rawValue }

        var label: String {
            switch self {
            case .shortSleep: "Sommeil sous"
            case .sleepEarly: "Sommeil plus tôt de"
            case .sleepLate: "Sommeil plus tard de"
            case .sleepIrregular: "Sommeil irrégulier au-delà de"
            case .energyHigh: "Énergie à"
            case .elevated: "Humeur haute à"
            case .depressed: "Humeur basse à"
            case .twoPole: "Deux pôles à"
            case .signs: "Signes d'un pôle"
            case .medMissed: "Traitement oublié"
            case .phq9: "PHQ-9 à"
            case .asrm: "ASRM à"
            }
        }

        /// Pôle du plan ouvert par la carte du signal.
        var defaultPole: Pole? {
            switch self {
            case .shortSleep, .sleepEarly, .energyHigh, .elevated, .asrm: .up
            case .sleepLate, .depressed, .phq9: .down
            case .sleepIrregular, .twoPole, .signs, .medMissed: nil
            }
        }

        /// Unité de seuil, pour l'aide à la saisie.
        var thresholdHint: String {
            switch self {
            case .shortSleep: "Heures"
            case .sleepEarly, .sleepLate, .sleepIrregular: "Minutes"
            case .energyHigh: "Niveau d'énergie, 1 à 2"
            case .elevated, .depressed, .twoPole: "Niveau, 1 à 3"
            case .signs: "Nombre de signes"
            case .medMissed: "Prises manquées"
            case .phq9: "Score, 0 à 27"
            case .asrm: "Score, 0 à 20"
            }
        }
    }

    var id: UUID
    var kind: Kind
    var threshold: Double
    var span: Int
    var stage: Int
    var isOn: Bool
    var notifies: Bool
    var pole: Pole?

    init(
        id: UUID = UUID(),
        kind: Kind,
        threshold: Double,
        span: Int,
        stage: Int = 1,
        isOn: Bool = true,
        notifies: Bool = false,
        pole: Pole? = nil
    ) {
        self.id = id
        self.kind = kind
        self.threshold = threshold
        self.span = span
        self.stage = stage
        self.isOn = isOn
        self.notifies = notifies
        self.pole = pole ?? kind.defaultPole
    }

    // Décodage tolérant : les sauvegardes 0.1 n'ont ni stage, ni isOn, ni notifies, ni pole.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(Kind.self, forKey: .kind)
        threshold = try container.decode(Double.self, forKey: .threshold)
        span = try container.decodeIfPresent(Int.self, forKey: .span) ?? 1
        stage = try container.decodeIfPresent(Int.self, forKey: .stage) ?? 1
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
        notifies = try container.decodeIfPresent(Bool.self, forKey: .notifies) ?? false
        pole = try container.decodeIfPresent(Pole.self, forKey: .pole) ?? kind.defaultPole
    }
}

/// Phrases des signaux. Les blancs restent vides tant qu'ils ne sont pas remplis.
enum AlertPhrase {
    static func blanks(_ kind: AlertRule.Kind) -> (threshold: Bool, span: Bool, pole: Bool) {
        switch kind {
        case .shortSleep, .sleepEarly, .sleepLate, .energyHigh, .elevated, .depressed:
            (true, true, false)
        case .signs:
            (true, true, true)
        case .twoPole, .phq9, .asrm, .medMissed:
            (kind != .medMissed, kind == .medMissed, false)
        case .sleepIrregular:
            (false, false, false)
        }
    }

    static func isComplete(kind: AlertRule.Kind, threshold: Double?, span: Int?, pole: Pole?) -> Bool {
        let blanks = blanks(kind)
        if blanks.threshold, (threshold ?? 0) <= 0 { return false }
        if blanks.span, (span ?? 0) <= 0 { return false }
        if blanks.pole, pole == nil { return false }
        return true
    }

    static func text(kind: AlertRule.Kind, threshold: Double?, span: Int?, pole: Pole?) -> String {
        let number = threshold.map(format) ?? "__"
        let days = span.map(String.init) ?? "__"
        let poleName = pole?.label ?? "Quand ça monte"
        switch kind {
        case .shortSleep:
            return "Si je dors moins de \(number) h pendant \(days) nuits"
        case .sleepEarly:
            return "Si mes nuits se décalent plus tôt de \(number) min pendant \(days) nuits"
        case .sleepLate:
            return "Si mes nuits se décalent plus tard de \(number) min pendant \(days) nuits"
        case .sleepIrregular:
            return "Si mes horaires de sommeil varient plus, ou moins, que d'habitude"
        case .energyHigh:
            return "Si mon énergie est à \(number) ou plus pendant \(days) jours"
        case .elevated:
            return "Si mon humeur haute est à \(number) ou plus pendant \(days) jours"
        case .depressed:
            return "Si mon humeur basse est à \(number) ou plus pendant \(days) jours"
        case .twoPole:
            return "Si humeur haute et humeur basse sont à \(number) ou plus le même jour"
        case .signs:
            return "Si je remarque \(number) signes de « \(poleName) » en \(days) jours"
        case .medMissed:
            return "Si j'oublie mon traitement \(days) jours de suite"
        case .phq9:
            return "Si mon score PHQ-9 est à \(number) ou plus"
        case .asrm:
            return "Si mon score ASRM est à \(number) ou plus"
        }
    }

    static func text(for rule: AlertRule) -> String {
        text(kind: rule.kind, threshold: rule.threshold, span: rule.span, pole: rule.pole)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Fusionne les contacts des deux plans, dédoublonnés par numéro.
enum ContactMerge {
    struct Result: Equatable {
        var contacts: [Contact]
        var helperIDs: [UUID]
        var professionalIDs: [UUID]
    }

    static func merge(
        planContacts: [Contact],
        helpers: [Contact],
        professionals: [Contact],
        helperIDs: [UUID] = [],
        professionalIDs: [UUID] = []
    ) -> Result {
        var contacts = planContacts
        func absorb(_ contact: Contact, role: ContactRole) -> UUID {
            let digits = contact.digits
            if !digits.isEmpty, let index = contacts.firstIndex(where: { $0.digits == digits }) {
                if contacts[index].role == nil { contacts[index].role = role }
                return contacts[index].id
            }
            if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                if contacts[index].role == nil { contacts[index].role = contact.role ?? role }
                return contacts[index].id
            }
            var copy = contact
            if copy.role == nil { copy.role = role }
            contacts.append(copy)
            return copy.id
        }

        let helpersResolved = helperIDs.isEmpty ? helpers.map { absorb($0, .trusted) } : helperIDs
        let prosResolved = professionalIDs.isEmpty ? professionals.map { absorb($0, .therapist) } : professionalIDs
        return Result(contacts: contacts, helperIDs: helpersResolved, professionalIDs: prosResolved)
    }
}

/// Reprend les bilans où la séance était cochée.
enum SessionImport {
    static func sessions(from logs: [DayLog], existing: [TherapySession], calendar: Calendar = .current) -> [TherapySession] {
        let known = Set(existing.map { calendar.startOfDay(for: $0.date) })
        return logs.filter(\.therapySession).compactMap { log in
            let day = calendar.startOfDay(for: log.day)
            guard !known.contains(day) else { return nil }
            return TherapySession(date: day, done: true)
        }
    }
}

/// La carte du point de la semaine reste trois jours, tant que le point n'est pas fait.
enum WeeklySchedule {
    static func showsCard(
        enabled: Bool,
        weekday: Int,
        everyTwoWeeks: Bool,
        paused: Bool,
        now: Date,
        surveyDates: [Date],
        calendar: Calendar = .current
    ) -> Bool {
        guard enabled, !paused else { return false }
        let today = calendar.startOfDay(for: now)
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard calendar.component(.weekday, from: day) == weekday else { continue }
            if everyTwoWeeks, calendar.component(.weekOfYear, from: day) % 2 != 0 { return false }
            let done = surveyDates.contains { calendar.startOfDay(for: $0) >= day }
            return !done
        }
        return false
    }
}
