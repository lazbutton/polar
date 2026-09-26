import Foundation
import SwiftData

@Model
final class Medication {
    var name: String = ""
    var dose: String = ""
    var slot: String = "soir"
    var reminder: Date?
    var isActive: Bool = true
    @Relationship(deleteRule: .nullify, inverse: \MedIntake.medication)
    var intakes: [MedIntake]? = []

    init(name: String, dose: String, slot: String) {
        self.name = name
        self.dose = dose
        self.slot = slot
    }
}

enum MedicationSlot {
    static let all = ["matin", "midi", "soir", "au besoin"]
}
