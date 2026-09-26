import Foundation
import SwiftData

@Model
final class MedIntake {
    var taken: Bool = true
    var at: Date = Date.now
    var doseChange: String?
    var medication: Medication?
    var dayLog: DayLog?

    init(medication: Medication, dayLog: DayLog, taken: Bool) {
        self.medication = medication
        self.dayLog = dayLog
        self.taken = taken
    }
}
