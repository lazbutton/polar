import Foundation
import SwiftData

@Model
final class CarePlan {
    // Mon plan 0.2 : signes par pôle et par palier, actions, contacts.
    var signs: [WarningSign] = []
    var actions: [PlanAction] = []
    var contacts: [Contact] = []
    var reviewedAt: Date?

    // Champs 0.1, gardés le temps de la migration (11.5).
    var warningSigns: [String] = []
    var whatHelps: [String] = []
    var trustedName: String?
    var trustedPhone: String?
    var therapistName: String?
    var therapistPhone: String?

    init() {}

    /// Signes d'un pôle et d'un palier donnés.
    func signs(pole: Pole, stage: PlanStage) -> [WarningSign] {
        signs.filter { $0.pole == pole && $0.stage == stage.rawValue }
    }

    /// Actions d'un pôle et d'un palier donnés.
    func actions(pole: Pole, stage: PlanStage) -> [PlanAction] {
        actions.filter { $0.pole == pole && $0.stage == stage.rawValue }
    }

    /// Signes encore sans pôle, à classer (repris de la 0.1).
    var unsortedSigns: [WarningSign] { signs.filter { $0.pole == nil } }

    @MainActor
    static func existing(in context: ModelContext) throws -> CarePlan? {
        var descriptor = FetchDescriptor<CarePlan>()
        return try context.fetch(descriptor).first
    }

    /// Un seul plan sur l'appareil. On le crée à la première ouverture de Mon plan.
    @MainActor
    static func findOrCreate(in context: ModelContext) throws -> CarePlan {
        if let plan = try existing(in: context) {
            return plan
        }
        let plan = CarePlan()
        context.insert(plan)
        return plan
    }
}
