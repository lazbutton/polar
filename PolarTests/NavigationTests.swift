import Foundation
import SwiftData
import Testing
@testable import Polar

@MainActor
struct RouterTests {
    @Test func unLienInterneResteDansLOnglet() {
        let router = Router()
        router.tab = .history
        router.push(.forPsy)
        #expect(router.history == [.forPsy])
        #expect(router.today.isEmpty)
        #expect(router.plan.isEmpty)
    }

    @Test func unRaccourciFermeLaFeuilleEtChoisitLOnglet() {
        let router = Router()
        router.tab = .today
        router.present(.weekly)
        router.openFromOutside(.safetyPlan)
        #expect(router.fill == nil)
        #expect(router.tab == .plan)
        #expect(router.plan == [.safetyPlan])
    }

    @Test func noterDepuisLExterieurOuvreUnMomentSurAujourdhui() {
        let router = Router()
        router.tab = .plan
        router.present(.weekly)
        router.openCapture()
        #expect(router.tab == .today)
        #expect(router.today.isEmpty)
        if case .moment(nil) = router.fill {} else {
            Issue.record("La feuille devrait être un nouveau moment")
        }
    }

    @Test func unContactResteDansMonPlan() {
        let router = Router()
        router.tab = .plan
        router.push(.contact(UUID()))
        #expect(router.plan.count == 1)
        #expect(router.today.isEmpty)
        #expect(router.history.isEmpty)
    }

    @Test func leBilanExterieurOuvreLaFeuilleDuJour() {
        let router = Router()
        router.openDayLog()
        guard case .dayLog = router.fill else {
            Issue.record("Feuille de bilan attendue")
            return
        }
        #expect(router.tab == .today)
    }
}

struct PhraseTests {
    @Test func unePhraseNeCommencePasRemplie() {
        #expect(AlertPhrase.isComplete(kind: .shortSleep, threshold: nil, span: nil, pole: nil) == false)
        #expect(AlertPhrase.text(kind: .shortSleep, threshold: nil, span: nil, pole: nil).contains("__"))
    }

    @Test func unePhraseCompleteActiveTermine() {
        #expect(AlertPhrase.isComplete(kind: .shortSleep, threshold: 5, span: 3, pole: nil))
        #expect(AlertPhrase.isComplete(kind: .sleepIrregular, threshold: nil, span: nil, pole: nil))
        #expect(AlertPhrase.isComplete(kind: .signs, threshold: 2, span: 3, pole: nil) == false)
        #expect(AlertPhrase.isComplete(kind: .signs, threshold: 2, span: 3, pole: .up))
    }
}

struct ContactMergeTests {
    @Test func leMemeNumeroNeFaitQuUnContact() {
        let shared = "06 12 34 56 78"
        let plan = [Contact(name: "Léa", phone: shared, role: .trusted)]
        let helper = Contact(name: "Léa B.", phone: "0612345678")
        let pro = Contact(name: "Dr Martin", phone: "01 02 03 04 05")
        let merged = ContactMerge.merge(
            planContacts: plan,
            helpers: [helper],
            professionals: [pro]
        )
        #expect(merged.contacts.count == 2)
        #expect(merged.helperIDs.count == 1)
        #expect(merged.helperIDs.first == plan[0].id)
        #expect(merged.professionalIDs.count == 1)
        #expect(merged.contacts.contains { $0.name == "Dr Martin" && $0.role == .therapist })
    }
}

@MainActor
struct SessionImportTests {
    @Test func unBilanCocheDevientUneSeance() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let log = DayLog(day: day)
        log.therapySession = true
        let plain = DayLog(day: day.addingTimeInterval(86_400))
        let created = SessionImport.sessions(from: [log, plain], existing: [])
        #expect(created.count == 1)
        #expect(created.first?.done == true)
        let again = SessionImport.sessions(from: [log], existing: created)
        #expect(again.isEmpty)
    }
}

struct WeeklyWindowTests {
    @Test func laCarteResteTroisJours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        // Jeudi 24 septembre 2026.
        let thursday = DateComponents(calendar: calendar, year: 2026, month: 9, day: 24, hour: 12).date!
        let saturday = DateComponents(calendar: calendar, year: 2026, month: 9, day: 26, hour: 12).date!
        let sunday = DateComponents(calendar: calendar, year: 2026, month: 9, day: 27, hour: 12).date!
        #expect(WeeklySchedule.showsCard(
            enabled: true, weekday: 5, everyTwoWeeks: false, paused: false,
            now: saturday, surveyDates: [], calendar: calendar
        ))
        #expect(WeeklySchedule.showsCard(
            enabled: true, weekday: 5, everyTwoWeeks: false, paused: false,
            now: sunday, surveyDates: [], calendar: calendar
        ) == false)
        #expect(WeeklySchedule.showsCard(
            enabled: true, weekday: 5, everyTwoWeeks: false, paused: false,
            now: saturday, surveyDates: [thursday], calendar: calendar
        ) == false)
    }
}

@MainActor
struct LockCallTests {
    @Test func lesUrgencesRestentQuandLePlanEstVide() {
        let titles = LockCalls.targets(plan: nil, safety: nil).map(\.title)
        #expect(titles == ["3114", "15"])
    }

    @Test func laPersonneVientDeLaListePartagee() throws {
        let context = try makeContext()
        let plan = CarePlan()
        let person = Contact(name: "Léa", phone: "06 11 22 33 44", role: .trusted)
        let therapist = Contact(name: "Dr Martin", phone: "01 02 03 04 05", role: .therapist)
        plan.contacts = [person, therapist]
        let safety = SafetyPlan()
        safety.helperIDs = [person.id]
        safety.professionalIDs = [therapist.id]
        context.insert(plan)
        context.insert(safety)
        let titles = LockCalls.targets(plan: plan, safety: safety).map(\.title)
        #expect(titles == ["Ma personne", "Ma psy", "3114", "15"])
    }
}

struct MoodLineTests {
    @Test func deuxPolesSeLisentsousLaCourbe() {
        let log = DayLog(day: .now)
        log.elevated = 2
        log.depressed = 2
        #expect(Insights.moodLine([log]) == "1 jour à deux pôles")
    }
}
