import Foundation
import SwiftData

/// Stockage SwiftData de l'iPhone, dans l'App Group pour que le widget et Siri écrivent au même endroit.
/// CloudKit reste coupé tant que la synchro n'est pas activée dans Réglages.
enum SharedStore {
    static let appGroupIdentifier = "group.fr.laz.polar"
    static let cloudKitContainerIdentifier = "iCloud.fr.laz.polar"

    /// Schéma 0.3 : ajoute les séances. Les propriétés nouvelles ont une valeur par défaut,
    /// SwiftData fait donc une migration légère depuis le schéma 0.2.
    static let schema = Schema([
        Moment.self,
        DayLog.self,
        Medication.self,
        MedIntake.self,
        CarePlan.self,
        SafetyPlan.self,
        SurveyResponse.self,
        LabResult.self,
        TherapySession.self,
    ])

    static let container: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            NSLog("Polar: le stockage actuel ne s'ouvre pas (\(error)). L'ancien fichier est mis de côté.")
            do {
                quarantineCurrentStore()
                UserDefaults(suiteName: appGroupIdentifier)?.set(false, forKey: "cloudKitEnabled")
                return try makeContainer(cloudKit: false)
            } catch {
                fatalError("Stockage indisponible : \(error)")
            }
        }
    }()

    static var cloudKitEnabled: Bool {
        UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: "cloudKitEnabled") ?? false
    }

    static func makeContainer(inMemory: Bool = false, cloudKit: Bool? = nil) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(
                UUID().uuidString,
                schema: schema,
                isStoredInMemoryOnly: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: configuration)
        }

        let useCloud = cloudKit ?? cloudKitEnabled
        if useCloud {
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupIdentifier),
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                UserDefaults(suiteName: appGroupIdentifier)?.set(false, forKey: "cloudKitEnabled")
            }
        }

        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Garde l'ancien fichier sqlite à côté, pour ne pas le perdre si le schéma 0.2 ne peut pas l'ouvrir.
    private static func quarantineCurrentStore() {
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        let url = configuration.url
        let folder = url.deletingLastPathComponent()
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let base = url.lastPathComponent
        for suffix in ["", "-shm", "-wal"] {
            let source = folder.appendingPathComponent(base + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = folder.appendingPathComponent("avant-0.2-\(stamp)-\(base)\(suffix)")
            try? FileManager.default.moveItem(at: source, to: destination)
        }
    }
}
