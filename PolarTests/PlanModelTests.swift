import Foundation
import SwiftData
import Testing
@testable import Polar

@MainActor
struct PlanModelTests {
    @Test func lesSignesSeFiltrentParPoleEtPalier() {
        let plan = CarePlan()
        plan.signs = [
            WarningSign(text: "Moins besoin de dormir", pole: .up, stage: 1),
            WarningSign(text: "Projets en rafale", pole: .up, stage: 2),
            WarningSign(text: "Envie de rien", pole: .down, stage: 1),
            WarningSign(text: "À classer"),
        ]
        #expect(plan.signs(pole: .up, stage: .early).count == 1)
        #expect(plan.signs(pole: .up, stage: .settled).first?.text == "Projets en rafale")
        #expect(plan.signs(pole: .down, stage: .early).count == 1)
        #expect(plan.unsortedSigns.count == 1)
    }

    @Test func unSeulPlanDeSecurite() throws {
        let context = try makeContext()
        #expect(try SafetyPlan.existing(in: context) == nil)
        let first = try SafetyPlan.findOrCreate(in: context)
        first.reasons = ["Mes enfants"]
        let second = try SafetyPlan.findOrCreate(in: context)
        #expect(first.persistentModelID == second.persistentModelID)
        #expect(second.reasons == ["Mes enfants"])
    }

    @Test func laSauvegardeCouvreLesNouveauxChamps() throws {
        let context = try makeContext()
        let moment = Moment(emotionKey: "calme", intensity: 4, source: "app")
        moment.forSession = true
        context.insert(moment)

        let log = DayLog(day: .now)
        log.energy = 1
        log.bedtime = .now.addingTimeInterval(-8 * 3600)
        log.wakeTime = .now
        log.factors = [FactorCount(key: "cafe", count: 3)]
        context.insert(log)

        let safety = SafetyPlan()
        safety.copingAlone = ["Respirer"]
        context.insert(safety)

        context.insert(SurveyResponse(instrument: "phq9", answers: [1, 1, 0, 1, 0, 0, 0, 0, 0]))
        try context.save()

        let data = try Backup.make(in: context)
        for moment in try context.fetch(FetchDescriptor<Moment>()) { context.delete(moment) }
        for log in try context.fetch(FetchDescriptor<DayLog>()) { context.delete(log) }
        for safety in try context.fetch(FetchDescriptor<SafetyPlan>()) { context.delete(safety) }
        for survey in try context.fetch(FetchDescriptor<SurveyResponse>()) { context.delete(survey) }
        try context.save()

        try Backup.replace(data: data, in: context)

        let restoredMoment = try context.fetch(FetchDescriptor<Moment>()).first
        #expect(restoredMoment?.forSession == true)
        let restoredLog = try context.fetch(FetchDescriptor<DayLog>()).first
        #expect(restoredLog?.energy == 1)
        #expect(restoredLog?.factors.first?.count == 3)
        #expect(try SafetyPlan.existing(in: context)?.copingAlone == ["Respirer"])
        #expect(try context.fetch(FetchDescriptor<SurveyResponse>()).first?.score == 4)
    }
}
