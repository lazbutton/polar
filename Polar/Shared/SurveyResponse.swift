import Foundation
import SwiftData

/// Une passation d'un questionnaire (PHQ-9, ASRM, GAD-7) : le point de la semaine.
@Model
final class SurveyResponse {
    var date: Date = Date.now
    var instrument: String = "phq9"     // phq9 · asrm · gad7
    var answers: [Int] = []
    var score: Int = 0

    init(instrument: String, answers: [Int], date: Date = .now) {
        self.instrument = instrument
        self.answers = answers
        self.score = answers.reduce(0, +)
        self.date = date
    }

    var questionnaire: Questionnaire? { Questionnaire.byID(instrument) }

    /// Réponse positive à l'item 9 du PHQ-9 (idées de mort ou de se faire du mal).
    var phq9Item9Positive: Bool {
        instrument == "phq9" && answers.count >= 9 && answers[8] > 0
    }
}
