import Foundation
import SwiftData

/// Séance passée ou prochaine. Les questions préparées vivent sur la séance à venir.
@Model
final class TherapySession {
    var date: Date = Date.now
    var done: Bool = false
    var questions: [String] = []

    init(date: Date, done: Bool = false, questions: [String] = []) {
        self.date = date
        self.done = done
        self.questions = questions
    }
}
