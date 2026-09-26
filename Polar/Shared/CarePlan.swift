import Foundation
import SwiftData

@Model
final class CarePlan {
    var warningSigns: [String] = []
    var whatHelps: [String] = []
    var trustedName: String?
    var trustedPhone: String?
    var therapistName: String?
    var therapistPhone: String?

    init() {}

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
