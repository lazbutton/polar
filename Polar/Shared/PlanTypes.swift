import Foundation

/// Pôle d'un signe ou d'une action de Mon plan.
enum Pole: String, Codable, Hashable, CaseIterable, Identifiable {
    case up    // vers le haut
    case down  // vers le bas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .up: "Quand ça monte"
        case .down: "Quand ça descend"
        }
    }
}

/// Palier d'un signe ou d'une action : premiers signes, ou ça s'installe.
enum PlanStage: Int, Codable, Hashable, CaseIterable, Identifiable {
    case early = 1     // premiers signes
    case settled = 2   // ça s'installe

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .early: "Premiers signes"
        case .settled: "Ça s'installe"
        }
    }
}

/// Un signe précurseur, avec les mots de la personne.
struct WarningSign: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var pole: Pole?          // nil pour les signes repris de la 0.1, à classer
    var stage: Int = 1       // 1 premiers signes · 2 ça s'installe

    init(id: UUID = UUID(), text: String, pole: Pole? = nil, stage: Int = 1) {
        self.id = id
        self.text = text
        self.pole = pole
        self.stage = stage
    }
}

/// Ce que je fais, qui je préviens, pour un pôle et un palier donnés.
struct PlanAction: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var pole: Pole
    var stage: Int

    init(id: UUID = UUID(), text: String, pole: Pole, stage: Int) {
        self.id = id
        self.text = text
        self.pole = pole
        self.stage = stage
    }
}

/// Un contact : personne de confiance, psy, médecin, urgences.
struct Contact: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var phone: String

    init(id: UUID = UUID(), name: String, phone: String) {
        self.id = id
        self.name = name
        self.phone = phone
    }

    var digits: String { phone.filter { $0.isNumber || $0 == "+" } }
}

/// Un facteur du jour compté (café, alcool, conflit…).
struct FactorCount: Codable, Hashable, Identifiable {
    var key: String
    var count: Int

    var id: String { key }

    init(key: String, count: Int = 0) {
        self.key = key
        self.count = count
    }
}

/// Catalogue des facteurs du jour, en option, exclus du PDF par défaut.
enum FactorCatalog {
    struct Factor: Identifiable, Hashable {
        let id: String
        let label: String
    }

    static let all: [Factor] = [
        Factor(id: "cafe", label: "Café"),
        Factor(id: "alcool", label: "Alcool"),
        Factor(id: "cannabis", label: "Cannabis"),
        Factor(id: "substance", label: "Autre substance"),
        Factor(id: "voyage", label: "Voyage ou décalage"),
        Factor(id: "conflit", label: "Conflit"),
        Factor(id: "evenement", label: "Événement marquant"),
        Factor(id: "nuitblanche", label: "Nuit blanche"),
    ]

    static func label(for key: String) -> String {
        all.first { $0.id == key }?.label ?? key
    }
}
