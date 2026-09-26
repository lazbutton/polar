import Foundation
import SwiftData
import Testing
@testable import Polar

struct CoherenceTests {
    @Test func sixCyclesParMinute() {
        #expect(CoherenceClock.period == 10)
        #expect(CoherenceClock.phase(elapsed: 0) == 0)
        #expect(CoherenceClock.phase(elapsed: 5) == 0.5)
        #expect(CoherenceClock.phase(elapsed: 10) == 0)
        #expect(CoherenceClock.phase(elapsed: 15) == 0.5)
        #expect(CoherenceClock.inhaling(phase: 0))
        #expect(CoherenceClock.inhaling(phase: 0.49))
        #expect(CoherenceClock.inhaling(phase: 0.5) == false)
        #expect(abs(CoherenceClock.amplitude(phase: 0)) < 0.0001)
        #expect(abs(CoherenceClock.amplitude(phase: 0.25) - 0.5) < 0.0001)
        #expect(abs(CoherenceClock.amplitude(phase: 0.5) - 1) < 0.0001)
        #expect(abs(CoherenceClock.amplitude(phase: 0.75) - 0.5) < 0.0001)
        #expect(CoherenceClock.secondsLeft(phase: 0) == 5)
        #expect(CoherenceClock.secondsLeft(phase: 0.2) == 3)
        #expect(CoherenceClock.secondsLeft(phase: 0.5) == 5)
        #expect(CoherenceClock.inspireOpacity(phase: 0) == 1)
        #expect(CoherenceClock.inspireOpacity(phase: 0.25) == 1)
        #expect(CoherenceClock.inspireOpacity(phase: 0.5) == 0)
        #expect(CoherenceClock.inspireOpacity(phase: 0.75) == 0)
    }
}

struct DistressTests {
    @Test func unMotDeDetresseOuvreLeSoutien() {
        #expect(Distress.containsSignal("je veux en finir"))
        #expect(Distress.containsSignal("J'ai envie de mourir") == true)
        #expect(Distress.containsSignal("je suis anxieux au travail") == false)
    }
}

struct AlertEngineTests {
    @Test func pasDeSignalSansRegle() {
        let hits = AlertEngine.hits(rules: [], logs: [])
        #expect(hits.isEmpty)
    }

    @Test func troisNuitsCourtesAllumentLeSignal() {
        let calendar = Calendar(identifier: .gregorian)
        let today = DateComponents(calendar: calendar, year: 2026, month: 9, day: 26).date!
        let logs = (0..<3).map { offset -> DayLog in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let log = DayLog(day: day, calendar: calendar)
            log.sleepHours = 4
            return log
        }
        let rule = AlertRule(kind: .shortSleep, threshold: 5, span: 3)
        let hits = AlertEngine.hits(rules: [rule], logs: logs, today: today, startHour: 0, calendar: calendar)
        #expect(hits.count == 1)
    }

    @Test func uneNuitLongueRomptLaSerie() {
        let calendar = Calendar(identifier: .gregorian)
        let today = DateComponents(calendar: calendar, year: 2026, month: 9, day: 26).date!
        let short = DayLog(day: today, calendar: calendar)
        short.sleepHours = 4
        let long = DayLog(day: calendar.date(byAdding: .day, value: -1, to: today)!, calendar: calendar)
        long.sleepHours = 8
        let rule = AlertRule(kind: .shortSleep, threshold: 5, span: 2)
        let hits = AlertEngine.hits(rules: [rule], logs: [short, long], today: today, startHour: 0, calendar: calendar)
        #expect(hits.isEmpty)
    }
}

struct InsightTests {
    @Test func leTraitementSeCompteEnJours() {
        let log = DayLog(day: .now)
        let medication = Medication(name: "Lithium", dose: "400 mg", slot: "soir")
        let intake = MedIntake(medication: medication, dayLog: log, taken: true)
        log.intakes = [intake]
        let interval = DateInterval(start: .now.addingTimeInterval(-86400), end: .now.addingTimeInterval(86400))
        let lines = Insights.lines(logs: [log], moments: [], rules: [], in: interval)
        #expect(lines.contains { $0.contains("Traitement pris 1 jour sur 1") })
    }
}

@MainActor
struct BackupTests {
    @Test func unExportSeReimporte() throws {
        let context = try makeContext()
        let moment = Moment(emotionKey: "calme", intensity: 4, source: "app")
        moment.thought = "Ça va"
        context.insert(moment)
        try context.save()
        let data = try Backup.make(in: context)
        context.delete(moment)
        try context.save()
        try Backup.replace(data: data, in: context)
        let restored = try context.fetch(FetchDescriptor<Moment>())
        #expect(restored.count == 1)
        #expect(restored.first?.thought == "Ça va")
        #expect(restored.first?.emotionKey == "calme")
    }
}
