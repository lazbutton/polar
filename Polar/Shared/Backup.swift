import Foundation
import SwiftData

struct Archive: Codable {
    var moments: [MomentDTO]
    var dayLogs: [DayLogDTO]
    var medications: [MedicationDTO]
    var intakes: [IntakeDTO]
    var plan: CarePlanDTO?
}

struct MomentDTO: Codable {
    var createdAt: Date
    var emotionKey: String?
    var intensity: Int?
    var thought: String?
    var behavior: String?
    var behaviorTags: [String]
    var associations: [String]
    var source: String
}

struct DayLogDTO: Codable {
    var day: Date
    var depressed: Int
    var elevated: Int
    var irritability: Int
    var anxiety: Int
    var sleepHours: Double?
    var sleepFromHealth: Bool
    var psychoticSymptoms: Bool?
    var weightKg: Double?
    var therapySession: Bool
    var note: String?
    var customMarks: [String]
}

struct MedicationDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var dose: String
    var slot: String
    var reminder: Date?
    var isActive: Bool
}

struct IntakeDTO: Codable {
    var medicationID: UUID
    var day: Date
    var taken: Bool
    var at: Date
    var doseChange: String?
}

struct CarePlanDTO: Codable {
    var warningSigns: [String]
    var whatHelps: [String]
    var trustedName: String?
    var trustedPhone: String?
    var therapistName: String?
    var therapistPhone: String?
}

enum Backup {
    @MainActor
    static func make(in context: ModelContext) throws -> Data {
        let moments = try context.fetch(FetchDescriptor<Moment>())
        let logs = try context.fetch(FetchDescriptor<DayLog>())
        let medications = try context.fetch(FetchDescriptor<Medication>())
        let intakes = try context.fetch(FetchDescriptor<MedIntake>())
        let plan = try CarePlan.existing(in: context)

        var medicationIDs: [PersistentIdentifier: UUID] = [:]
        let medicationDTOs = medications.map { medication -> MedicationDTO in
            let id = UUID()
            medicationIDs[medication.persistentModelID] = id
            return MedicationDTO(
                id: id,
                name: medication.name,
                dose: medication.dose,
                slot: medication.slot,
                reminder: medication.reminder,
                isActive: medication.isActive
            )
        }

        let archive = Archive(
            moments: moments.map {
                MomentDTO(
                    createdAt: $0.createdAt,
                    emotionKey: $0.emotionKey,
                    intensity: $0.intensity,
                    thought: $0.thought,
                    behavior: $0.behavior,
                    behaviorTags: $0.behaviorTags,
                    associations: $0.associations,
                    source: $0.source
                )
            },
            dayLogs: logs.map {
                DayLogDTO(
                    day: $0.day,
                    depressed: $0.depressed,
                    elevated: $0.elevated,
                    irritability: $0.irritability,
                    anxiety: $0.anxiety,
                    sleepHours: $0.sleepHours,
                    sleepFromHealth: $0.sleepFromHealth,
                    psychoticSymptoms: $0.psychoticSymptoms,
                    weightKg: $0.weightKg,
                    therapySession: $0.therapySession,
                    note: $0.note,
                    customMarks: $0.customMarks
                )
            },
            medications: medicationDTOs,
            intakes: intakes.compactMap { intake in
                guard let medication = intake.medication,
                      let id = medicationIDs[medication.persistentModelID],
                      let day = intake.dayLog?.day else { return nil }
                return IntakeDTO(medicationID: id, day: day, taken: intake.taken, at: intake.at, doseChange: intake.doseChange)
            },
            plan: plan.map {
                CarePlanDTO(
                    warningSigns: $0.warningSigns,
                    whatHelps: $0.whatHelps,
                    trustedName: $0.trustedName,
                    trustedPhone: $0.trustedPhone,
                    therapistName: $0.therapistName,
                    therapistPhone: $0.therapistPhone
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    @MainActor
    static func replace(data: Data, in context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(Archive.self, from: data)

        for moment in try context.fetch(FetchDescriptor<Moment>()) { context.delete(moment) }
        for intake in try context.fetch(FetchDescriptor<MedIntake>()) { context.delete(intake) }
        for log in try context.fetch(FetchDescriptor<DayLog>()) { context.delete(log) }
        for medication in try context.fetch(FetchDescriptor<Medication>()) { context.delete(medication) }
        if let plan = try CarePlan.existing(in: context) { context.delete(plan) }
        try context.save()

        for dto in archive.moments {
            let moment = Moment(emotionKey: dto.emotionKey, intensity: dto.intensity, source: dto.source)
            moment.createdAt = dto.createdAt
            moment.thought = dto.thought
            moment.behavior = dto.behavior
            moment.behaviorTags = dto.behaviorTags
            moment.associations = dto.associations
            context.insert(moment)
        }

        var logsByDay: [Date: DayLog] = [:]
        for dto in archive.dayLogs {
            let log = DayLog(day: dto.day)
            log.depressed = dto.depressed
            log.elevated = dto.elevated
            log.irritability = dto.irritability
            log.anxiety = dto.anxiety
            log.sleepHours = dto.sleepHours
            log.sleepFromHealth = dto.sleepFromHealth
            log.psychoticSymptoms = dto.psychoticSymptoms
            log.weightKg = dto.weightKg
            log.therapySession = dto.therapySession
            log.note = dto.note
            log.customMarks = dto.customMarks
            context.insert(log)
            logsByDay[log.day] = log
        }

        var medicationsByID: [UUID: Medication] = [:]
        for dto in archive.medications {
            let medication = Medication(name: dto.name, dose: dto.dose, slot: dto.slot)
            medication.reminder = dto.reminder
            medication.isActive = dto.isActive
            context.insert(medication)
            medicationsByID[dto.id] = medication
        }

        for dto in archive.intakes {
            guard let medication = medicationsByID[dto.medicationID] else { continue }
            let log = logsByDay[Calendar.current.startOfDay(for: dto.day)] ?? {
                let created = DayLog(day: dto.day)
                context.insert(created)
                logsByDay[created.day] = created
                return created
            }()
            let intake = MedIntake(medication: medication, dayLog: log, taken: dto.taken)
            intake.at = dto.at
            intake.doseChange = dto.doseChange
            context.insert(intake)
        }

        if let dto = archive.plan {
            let plan = CarePlan()
            plan.warningSigns = dto.warningSigns
            plan.whatHelps = dto.whatHelps
            plan.trustedName = dto.trustedName
            plan.trustedPhone = dto.trustedPhone
            plan.therapistName = dto.therapistName
            plan.therapistPhone = dto.therapistPhone
            context.insert(plan)
        }
        try context.save()
    }
}
