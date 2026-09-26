import Foundation
import SwiftData

/// Stockage SwiftData de l'iPhone, dans l'App Group pour que le widget et Siri écrivent au même endroit.
/// CloudKit reste coupé tant que la synchro n'est pas activée dans Réglages.
enum SharedStore {
    static let appGroupIdentifier = "group.fr.laz.polar"
    static let cloudKitContainerIdentifier = "iCloud.fr.laz.polar"

    static let schema = Schema([
        Moment.self,
        DayLog.self,
        Medication.self,
        MedIntake.self,
        CarePlan.self,
    ])

    static let container: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Stockage indisponible : \(error)")
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
}
