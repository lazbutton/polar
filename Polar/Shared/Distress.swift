import Foundation

enum Distress {
    static let phrases = [
        "me suicider",
        "suicide",
        "me tuer",
        "plus envie de vivre",
        "envie de mourir",
        "en finir",
        "me faire du mal",
    ]

    static func containsSignal(_ text: String) -> Bool {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        return phrases.contains { phrase in
            folded.contains(phrase.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")))
        }
    }
}
