import Foundation
import HealthKit

struct Emotion: Identifiable, Hashable {
    let id: String
    let label: String
    let sign: Double
    let healthLabel: HKStateOfMind.Label?

    func valence(intensity: Int) -> Double { sign * Double(intensity) / 10 }
}

enum EmotionCatalog {
    static let all: [Emotion] = [
        Emotion(id: "joie", label: "Joie", sign: 1, healthLabel: .joyful),
        Emotion(id: "calme", label: "Calme", sign: 1, healthLabel: .calm),
        Emotion(id: "soulagement", label: "Soulagement", sign: 1, healthLabel: .relieved),
        Emotion(id: "fierte", label: "Fierté", sign: 1, healthLabel: .proud),
        Emotion(id: "gratitude", label: "Gratitude", sign: 1, healthLabel: .grateful),
        Emotion(id: "espoir", label: "Espoir", sign: 1, healthLabel: .hopeful),
        Emotion(id: "enthousiasme", label: "Enthousiasme", sign: 1, healthLabel: .excited),
        Emotion(id: "exaltation", label: "Exaltation", sign: 1, healthLabel: .excited),
        Emotion(id: "indifference", label: "Indifférence", sign: 0, healthLabel: .indifferent),
        Emotion(id: "tristesse", label: "Tristesse", sign: -1, healthLabel: .sad),
        Emotion(id: "anxiete", label: "Anxiété", sign: -1, healthLabel: .anxious),
        Emotion(id: "inquietude", label: "Inquiétude", sign: -1, healthLabel: .worried),
        Emotion(id: "stress", label: "Stress", sign: -1, healthLabel: .stressed),
        Emotion(id: "colere", label: "Colère", sign: -1, healthLabel: .angry),
        Emotion(id: "irritation", label: "Irritation", sign: -1, healthLabel: .irritated),
        Emotion(id: "frustration", label: "Frustration", sign: -1, healthLabel: .frustrated),
        Emotion(id: "honte", label: "Honte", sign: -1, healthLabel: .ashamed),
        Emotion(id: "culpabilite", label: "Culpabilité", sign: -1, healthLabel: .guilty),
        Emotion(id: "solitude", label: "Solitude", sign: -1, healthLabel: .lonely),
        Emotion(id: "epuisement", label: "Épuisement", sign: -1, healthLabel: .drained),
        Emotion(id: "debordement", label: "Débordement", sign: -1, healthLabel: .overwhelmed),
        Emotion(id: "decouragement", label: "Découragement", sign: -1, healthLabel: .discouraged),
        Emotion(id: "desespoir", label: "Désespoir", sign: -1, healthLabel: .hopeless),
        Emotion(id: "peur", label: "Peur", sign: -1, healthLabel: .scared),
        Emotion(id: "agitation", label: "Agitation", sign: -1, healthLabel: nil),
    ]

    static let keys = all.map(\.id)

    static func emotion(for key: String) -> Emotion? {
        all.first { $0.id == key }
    }
}
