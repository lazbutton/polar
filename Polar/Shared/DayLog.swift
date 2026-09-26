import Foundation
import SwiftData

@Model
final class DayLog {
    var day: Date = Date.now
    var depressed: Int = 0
    var elevated: Int = 0
    var irritability: Int = 0
    var anxiety: Int = 0
    var sleepHours: Double?
    var sleepFromHealth: Bool = false
    var psychoticSymptoms: Bool?
    var weightKg: Double?
    var therapySession: Bool = false
    var note: String?
    var customMarks: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \MedIntake.dayLog)
    var intakes: [MedIntake]? = []

    init(day: Date, calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: day)
    }

    /// Bilan déjà enregistré pour le jour logique de `date`, s'il existe.
    /// L'absence de ligne signifie que le bilan n'a pas été fait : des jauges à zéro sont une saisie.
    @MainActor
    static func existing(
        for date: Date = .now,
        startHour: Int = 4,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> DayLog? {
        let targetDay = date.logicalDay(startHour: startHour, calendar: calendar)
        var descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate<DayLog> { $0.day == targetDay }
        )
        return try context.fetch(descriptor).first
    }

    /// Retrouve le bilan du jour logique, ou le crée. Un seul bilan par jour.
    /// SwiftData n'impose pas l'unicité : elle est incompatible avec CloudKit.
    @MainActor
    static func findOrCreate(
        for date: Date = .now,
        startHour: Int = 4,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> DayLog {
        if let log = try existing(for: date, startHour: startHour, calendar: calendar, in: context) {
            return log
        }
        let log = DayLog(day: date.logicalDay(startHour: startHour, calendar: calendar), calendar: calendar)
        context.insert(log)
        return log
    }
}
