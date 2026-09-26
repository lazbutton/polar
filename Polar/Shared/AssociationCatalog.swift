import Foundation
import HealthKit

struct Association: Identifiable, Hashable {
    let id: String
    let label: String
    let healthAssociation: HKStateOfMind.Association
}

enum AssociationCatalog {
    static let all: [Association] = [
        Association(id: "travail", label: "Travail", healthAssociation: .work),
        Association(id: "famille", label: "Famille", healthAssociation: .family),
        Association(id: "couple", label: "Couple", healthAssociation: .partner),
        Association(id: "amis", label: "Amis", healthAssociation: .friends),
        Association(id: "sante", label: "Santé", healthAssociation: .health),
        Association(id: "argent", label: "Argent", healthAssociation: .money),
        Association(id: "communaute", label: "Communauté", healthAssociation: .community),
        Association(id: "actualite", label: "Actualité", healthAssociation: .currentEvents),
        Association(id: "rencontres", label: "Rencontres", healthAssociation: .dating),
        Association(id: "etudes", label: "Études", healthAssociation: .education),
        Association(id: "sport", label: "Sport", healthAssociation: .fitness),
        Association(id: "loisirs", label: "Loisirs", healthAssociation: .hobbies),
        Association(id: "identite", label: "Identité", healthAssociation: .identity),
        Association(id: "soin", label: "Soin de soi", healthAssociation: .selfCare),
        Association(id: "spiritualite", label: "Spiritualité", healthAssociation: .spirituality),
        Association(id: "taches", label: "Tâches", healthAssociation: .tasks),
        Association(id: "voyage", label: "Voyage", healthAssociation: .travel),
        Association(id: "meteo", label: "Météo", healthAssociation: .weather),
    ]

    static let keys = all.map(\.id)

    static func association(for key: String) -> Association? {
        all.first { $0.id == key }
    }
}
