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
