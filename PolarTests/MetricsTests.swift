import Foundation
import Testing
@testable import Polar

private enum Clock {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: y, month: m, day: d, hour: h, minute: min).date!
    }

    static func night(midHour: Int, on day: Date) -> SleepNight {
        let bed = calendar.date(bySettingHour: max(midHour - 1, 0), minute: 0, second: 0, of: day)!
        let wake = calendar.date(bySettingHour: midHour + 1, minute: 0, second: 0, of: day)!
        return SleepNight(bedtime: bed, wake: wake)
    }
}

struct SleepMetricsTests {
    @Test func laDureeEtLeMilieuDuSommeil() {
        let night = SleepNight(bedtime: Clock.date(2026, 9, 25, 23, 40), wake: Clock.date(2026, 9, 26, 7, 10))
        #expect(abs(night.duration - 7.5 * 3600) < 1)
        #expect(abs(night.midpointMinutes(calendar: Clock.calendar) - 565) < 0.5)
    }

    @Test func lEcartTypeEstCeluiDUnEchantillon() {
        #expect(abs(SleepMetrics.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9]) - (32.0 / 7).squareRoot()) < 0.0001)
        #expect(SleepMetrics.standardDeviation([5]) == 0)
    }

    @Test func laMediane() {
        #expect(SleepMetrics.median([1, 2, 3, 4, 5]) == 3)
        #expect(SleepMetrics.median([1, 2, 3, 4]) == 2.5)
    }

    @Test func leDecalageDuMilieuDemandeDixNuits() {
        let today = Clock.date(2026, 9, 26, 12)
        let reference = (1...12).map { Clock.night(midHour: 3, on: Clock.calendar.date(byAdding: .day, value: -$0, to: today)!) }
        let tonight = Clock.night(midHour: 4, on: today)
        #expect(SleepMetrics.midpointShift(tonight: tonight, previous: reference, calendar: Clock.calendar).map { abs($0 - 60) < 0.5 } ?? false)
        #expect(SleepMetrics.midpointShift(tonight: tonight, previous: Array(reference.prefix(5)), calendar: Clock.calendar) == nil)
    }

    @Test func laVariabiliteDemandeCinqNuits() {
        let nights = (0..<4).map { Clock.night(midHour: 3, on: Clock.date(2026, 9, 20 + $0)) }
        #expect(SleepMetrics.variability(nights, calendar: Clock.calendar) == nil)
    }
}

struct InstabilityTests {
    @Test func laMoyenneDesEcartsSuccessifs() {
        #expect(Instability.meanAbsoluteSuccessiveDifference([0, 1, 0, 1, 0, 1, 0, 1]).map { abs($0 - 1) < 0.0001 } ?? false)
        #expect(Instability.meanAbsoluteSuccessiveDifference([0, 1, 2]) == nil)
    }

    @Test func lesJoursManquantsCoupentLaPaire() {
        #expect(Instability.meanAbsoluteSuccessiveDifference([0, nil, 2, 3, 4, 5, 6, 7, 8]) == nil)
        #expect(Instability.meanAbsoluteSuccessiveDifference([0, nil, 2, 3, 4, 5, 6, 7, 8, 9, 10]) != nil)
    }

    @Test func lAxeEtLesDeuxPoles() {
        let mixed = DayLog(day: .now)
        mixed.elevated = 2
        mixed.depressed = 1
        #expect(Instability.moodAxis(mixed) == 1)
        #expect(Instability.isTwoPoleDay(mixed))

        let up = DayLog(day: .now)
        up.elevated = 2
        #expect(Instability.isTwoPoleDay(up) == false)
    }
}

struct QuestionnaireTests {
    @Test func lePHQ9() {
        let phq = Questionnaire.phq9
        #expect(phq.questions.count == 9)
        #expect(phq.maxScore == 27)
        #expect(phq.score([1, 1, 1, 1, 1, 0, 1, 1, 0]) == 7)
        #expect(phq.cutoffLabel(for: 4) == nil)
        #expect(phq.cutoffLabel(for: 7) == "léger")
        #expect(phq.cutoffLabel(for: 22) == "sévère")
    }

    @Test func lASRMEtSonSeuilAsix() {
        let asrm = Questionnaire.asrm
        #expect(asrm.questions.count == 5)
        #expect(asrm.maxScore == 20)
        #expect(asrm.cutoffLabel(for: 5) == nil)
        #expect(asrm.cutoffLabel(for: 6) != nil)
    }

    @Test func leGAD7EstEnOption() {
        #expect(Questionnaire.gad7.questions.count == 7)
        #expect(Questionnaire.gad7.maxScore == 21)
        #expect(Questionnaire.weekly(includeGAD7: false).count == 2)
        #expect(Questionnaire.weekly(includeGAD7: true).count == 3)
    }

    @Test func lItem9DuPHQ9() {
        let calme = SurveyResponse(instrument: "phq9", answers: [1, 1, 0, 1, 0, 0, 0, 0, 0])
        let alerte = SurveyResponse(instrument: "phq9", answers: [1, 1, 0, 1, 0, 0, 0, 0, 2])
        #expect(calme.phq9Item9Positive == false)
        #expect(alerte.phq9Item9Positive)
    }
}

struct SignalTests {
    private let today = Clock.date(2026, 9, 26, 12)

    private func log(_ offset: Int, _ configure: (DayLog) -> Void) -> DayLog {
        let day = Clock.calendar.startOfDay(for: Clock.calendar.date(byAdding: .day, value: -offset, to: today)!)
        let log = DayLog(day: day)
        configure(log)
        return log
    }

    @Test func energieHauteDeuxJours() {
        let logs = (0..<2).map { off in log(off) { $0.energy = 2 } }
        let rule = AlertRule(kind: .energyHigh, threshold: 1, span: 2)
        #expect(AlertEngine.hits(rules: [rule], logs: logs, today: today, startHour: 0, calendar: Clock.calendar).count == 1)
    }

    @Test func unSignalEteintNeSeDeclenchePas() {
        let logs = (0..<3).map { off in log(off) { $0.sleepHours = 4 } }
        let rule = AlertRule(kind: .shortSleep, threshold: 5, span: 3, isOn: false)
        #expect(AlertEngine.hits(rules: [rule], logs: logs, today: today, startHour: 0, calendar: Clock.calendar).isEmpty)
    }

    @Test func deuxPolesLeMemeJour() {
        let logs = [log(0) { $0.elevated = 1; $0.depressed = 1 }]
        let rule = AlertRule(kind: .twoPole, threshold: 1, span: 1)
        #expect(AlertEngine.hits(rules: [rule], logs: logs, today: today, startHour: 0, calendar: Clock.calendar).count == 1)
    }

    @Test func leQuestionnaireAuDessusDuSeuil() {
        let surveys = [SurveyResponse(instrument: "asrm", answers: [2, 1, 2, 1, 1])] // score 7
        let rule = AlertRule(kind: .asrm, threshold: 6, span: 1)
        #expect(AlertEngine.hits(rules: [rule], logs: [], surveys: surveys, today: today, startHour: 0, calendar: Clock.calendar).count == 1)
    }

    @Test func lesSignesDUnPoleTransmettentLePole() {
        let plan = CarePlan()
        let s1 = WarningSign(text: "Moins besoin de dormir", pole: .up, stage: 1)
        let s2 = WarningSign(text: "Projets en rafale", pole: .up, stage: 1)
        plan.signs = [s1, s2]
        let logs = [log(0) { $0.signsSeen = [s1.id, s2.id] }]
        let rule = AlertRule(kind: .signs, threshold: 2, span: 1, pole: .up)
        let hits = AlertEngine.hits(rules: [rule], logs: logs, plan: plan, today: today, startHour: 0, calendar: Clock.calendar)
        #expect(hits.count == 1)
        #expect(hits.first?.pole == .up)
    }

    @Test func sommeilPlusTardQueDHabitude() {
        let logs = (0...11).map { off in
            log(off) { l in
                let mid = off == 0 ? 4 : 3
                l.bedtime = Clock.calendar.date(bySettingHour: max(mid - 1, 0), minute: 0, second: 0, of: l.day)!
                l.wakeTime = Clock.calendar.date(bySettingHour: mid + 1, minute: 0, second: 0, of: l.day)!
            }
        }
        let rule = AlertRule(kind: .sleepLate, threshold: 45, span: 1)
        #expect(AlertEngine.hits(rules: [rule], logs: logs, today: today, startHour: 0, calendar: Clock.calendar).count == 1)
    }
}
