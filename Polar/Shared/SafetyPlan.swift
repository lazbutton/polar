import Foundation
import SwiftData

/// Plan de sécurité en six étapes (modèle Stanley-Brown), à remplir avec ta psy.
@Model
final class SafetyPlan {
    var reasons: [String] = []          // ce qui compte pour moi
    var warningSigns: [String] = []     // 1. mes signes d'alerte
    var copingAlone: [String] = []      // 2. me calmer seul
    var distractions: [String] = []     // 3. personnes et lieux qui apaisent
    var helpers: [Contact] = []         // 4. conservé pour la migration 0.2
    var professionals: [Contact] = []   // 5. conservé pour la migration 0.2
    var helperIDs: [UUID] = []          // 4. identifiants dans CarePlan.contacts
    var professionalIDs: [UUID] = []    // 5. identifiants dans CarePlan.contacts
    var safeEnvironment: [String] = []  // 6. rendre mon environnement sûr
    var reviewedAt: Date?

    init() {}

    @MainActor
    static func existing(in context: ModelContext) throws -> SafetyPlan? {
        try context.fetch(FetchDescriptor<SafetyPlan>()).first
    }

    /// Un seul plan de sécurité sur l'appareil.
    @MainActor
    static func findOrCreate(in context: ModelContext) throws -> SafetyPlan {
        if let plan = try existing(in: context) { return plan }
        let plan = SafetyPlan()
        context.insert(plan)
        return plan
    }
}
