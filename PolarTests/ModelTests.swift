import Foundation
import SwiftData
import Testing
@testable import Polar

struct LogicalDayTests {
    @Test func avantLaBasculeComptePourLaVeille() {
        let calendar = Paris.calendar
        let date = Paris.date(2026, 9, 26, 3, 59)
        let day = date.logicalDay(startHour: 4, calendar: calendar)

        #expect(calendar.component(.day, from: day) == 25)
        #expect(calendar.component(.month, from: day) == 9)
        #expect(calendar.component(.hour, from: day) == 0)
    }

    @Test func aLHeureDeBasculeLeJourCommence() {
        let calendar = Paris.calendar
        let date = Paris.date(2026, 9, 26, 4, 0)
        let day = date.logicalDay(startHour: 4, calendar: calendar)

        #expect(calendar.component(.day, from: day) == 26)
    }

    @Test func uneHeureDeBasculeReglable() {
        let calendar = Paris.calendar
        let before = Paris.date(2026, 9, 26, 5, 59)
        let after = Paris.date(2026, 9, 26, 6, 0)

        #expect(calendar.component(.day, from: before.logicalDay(startHour: 6, calendar: calendar)) == 25)
        #expect(calendar.component(.day, from: after.logicalDay(startHour: 6, calendar: calendar)) == 26)
    }
}

struct SleepNightTests {
    @Test func coucherAQuatreHeuresResteLeMatinDuLever() {
        let calendar = Paris.calendar
        let logicalDay = Paris.date(2026, 9, 26, 0, 0)
        let bed = Paris.date(2026, 9, 25, 4, 0)
        let wake = Paris.date(2026, 9, 26, 11, 30)
        let night = SleepNight.anchored(bedtime: bed, wake: wake, on: logicalDay, calendar: calendar)

        #expect(night?.duration == 7.5 * 3600)
        #expect(calendar.component(.day, from: night!.bedtime) == 26)
        #expect(calendar.component(.hour, from: night!.bedtime) == 4)
    }

    @Test func coucherLeSoirResteLaVeille() {
        let calendar = Paris.calendar
        let logicalDay = Paris.date(2026, 9, 26, 0, 0)
        let bed = Paris.date(2026, 9, 26, 23, 0)
        let wake = Paris.date(2026, 9, 26, 7, 0)
        let night = SleepNight.anchored(bedtime: bed, wake: wake, on: logicalDay, calendar: calendar)

        #expect(night?.duration == 8 * 3600)
        #expect(calendar.component(.day, from: night!.bedtime) == 25)
        #expect(calendar.component(.hour, from: night!.bedtime) == 23)
    }
}

@MainActor
struct DayLogTests {
    @Test func pasDeBilanTantQueRienNEstNote() throws {
        let context = try makeContext()
        let found = try DayLog.existing(for: Paris.date(2026, 9, 26, 21, 0), calendar: Paris.calendar, in: context)
        #expect(found == nil)
    }

    @Test func laNuitAvantQuatreHeuresResteLaVeille() throws {
        let context = try makeContext()
        let calendar = Paris.calendar
        let evening = try DayLog.findOrCreate(for: Paris.date(2026, 9, 25, 22, 0), calendar: calendar, in: context)
        let night = try DayLog.findOrCreate(for: Paris.date(2026, 9, 26, 3, 30), calendar: calendar, in: context)
        let morning = try DayLog.findOrCreate(for: Paris.date(2026, 9, 26, 4, 0), calendar: calendar, in: context)

        #expect(evening.persistentModelID == night.persistentModelID)
        #expect(morning.persistentModelID != evening.persistentModelID)
        #expect(try context.fetch(FetchDescriptor<DayLog>()).count == 2)
    }

    @Test func leJourEstNormaliseAuDebutDeJournee() {
        let calendar = Paris.calendar
        let log = DayLog(day: Paris.date(2026, 9, 26, 18, 40), calendar: calendar)
        #expect(calendar.component(.hour, from: log.day) == 0)
        #expect(calendar.component(.day, from: log.day) == 26)
    }
}

@MainActor
struct StoreTests {
    @Test func unMomentIncompletNAttendQueLEmotion() throws {
        let context = try makeContext()
        let moment = Moment(emotionKey: "anxiete", intensity: 6, source: "app")
        context.insert(moment)
        #expect(moment.isComplete == false)

        moment.thought = "Tout le monde va me juger"
        moment.behavior = "Rester chez moi"
        #expect(moment.isComplete)
    }

    @Test func unePriseResteAttacheeAuTraitementEtAuBilan() throws {
        let context = try makeContext()
        let log = try DayLog.findOrCreate(for: Paris.date(2026, 9, 26, 21, 0), calendar: Paris.calendar, in: context)
        let medication = Medication(name: "Lithium", dose: "400 mg", slot: "soir")
        context.insert(medication)
        context.insert(MedIntake(medication: medication, dayLog: log, taken: true))
        try context.save()

        #expect(medication.isActive)
        #expect(log.intakes?.count == 1)
        #expect(log.intakes?.first?.medication?.name == "Lithium")
    }

    @Test func unSeulPlan() throws {
        let context = try makeContext()
        #expect(try CarePlan.existing(in: context) == nil)
        let first = try CarePlan.findOrCreate(in: context)
        first.trustedName = "Camille"
        let second = try CarePlan.findOrCreate(in: context)
        #expect(first.persistentModelID == second.persistentModelID)
        #expect(second.trustedName == "Camille")
    }
}

struct EmotionCatalogTests {
    @Test func leCatalogueCouvreLaSpec() {
        #expect(EmotionCatalog.all.count == 25)
        #expect(Set(EmotionCatalog.keys).count == 25)

        #expect(EmotionCatalog.emotion(for: "joie")?.healthLabel == .joyful)
        #expect(EmotionCatalog.emotion(for: "joie")?.valence(intensity: 6) == 0.6)
        #expect(EmotionCatalog.emotion(for: "anxiete")?.valence(intensity: 10) == -1)
        #expect(EmotionCatalog.emotion(for: "indifference")?.valence(intensity: 8) == 0)
        #expect(EmotionCatalog.emotion(for: "exaltation")?.healthLabel == .excited)
        #expect(EmotionCatalog.emotion(for: "agitation")?.healthLabel == nil)
        #expect(EmotionCatalog.emotion(for: "mot-libre") == nil)
    }

    @Test func lesAssociationsReprennentCellesDeSante() {
        #expect(AssociationCatalog.all.count == 18)
        #expect(Set(AssociationCatalog.keys).count == 18)
        #expect(AssociationCatalog.association(for: "travail")?.healthAssociation == .work)
        #expect(AssociationCatalog.association(for: "couple")?.healthAssociation == .partner)
        #expect(AssociationCatalog.association(for: "argent")?.label == "Argent")
    }
}

@MainActor
func makeContext() throws -> ModelContext {
    let container = try SharedStore.makeContainer(inMemory: true)
    return ModelContext(container)
}

private enum Paris {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ).date!
    }
}
