import Foundation
import SwiftData

/// Migration 0.1 → 0.2 en code : toutes les nouveautés sont optionnelles ou par défaut,
/// SwiftData gère donc le schéma de façon légère. Ici on ne fait que porter les données
/// de Mon plan (0.1) vers les nouveaux champs, une seule fois, après une sauvegarde.
enum Migration {
    private static let flagKey = "didMigrateToV2"

    static var isDone: Bool {
        defaults?.bool(forKey: flagKey) ?? false
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.appGroupIdentifier)
    }

    @MainActor
    static func runIfNeeded(in context: ModelContext) {
        guard !isDone else { return }
        // Sauvegarde JSON automatique avant tout changement.
        backup(in: context)

        if let plan = try? CarePlan.existing(in: context) {
            migratePlan(plan, in: context)
        }
        defaults?.set(true, forKey: flagKey)
        try? context.save()
    }

    @MainActor
    private static func backup(in context: ModelContext) {
        guard let data = try? Backup.make(in: context) else { return }
        let name = "polar-backup-avant-0.2.json"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent(name))
    }

    /// Chaque ancien signe devient un WarningSign sans pôle (à classer),
    /// chaque « ce qui t'aide » passe dans le plan de sécurité (me calmer seul).
    @MainActor
    private static func migratePlan(_ plan: CarePlan, in context: ModelContext) {
        if plan.signs.isEmpty, !plan.warningSigns.isEmpty {
            plan.signs = plan.warningSigns.map { WarningSign(text: $0, pole: nil, stage: 1) }
        }

        if plan.contacts.isEmpty {
            var contacts: [Contact] = []
            if let name = plan.trustedName, let phone = plan.trustedPhone {
                contacts.append(Contact(name: name, phone: phone))
            }
            if let name = plan.therapistName, let phone = plan.therapistPhone {
                contacts.append(Contact(name: name, phone: phone))
            }
            plan.contacts = contacts
        }

        let safety = (try? SafetyPlan.findOrCreate(in: context)) ?? SafetyPlan()
        if safety.copingAlone.isEmpty, !plan.whatHelps.isEmpty {
            safety.copingAlone = plan.whatHelps
        }
        if safety.helpers.isEmpty {
            if let name = plan.trustedName, let phone = plan.trustedPhone {
                safety.helpers = [Contact(name: name, phone: phone)]
            }
        }
        if safety.professionals.isEmpty {
            if let name = plan.therapistName, let phone = plan.therapistPhone {
                safety.professionals = [Contact(name: name, phone: phone)]
            }
        }
    }
}
