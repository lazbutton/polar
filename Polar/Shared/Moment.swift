import Foundation
import SwiftData

@Model
final class Moment {
    var createdAt: Date = Date.now
    var emotionKey: String?
    var intensity: Int?
    var thought: String?
    var behavior: String?
    var behaviorTags: [String] = []
    var associations: [String] = []
    var source: String = "app"
    var healthSampleID: UUID?
    /// « À en parler avec ma psy » : le moment rejoint Préparer ma séance.
    var forSession: Bool = false

    init(emotionKey: String? = nil, intensity: Int? = nil, source: String = "app") {
        self.emotionKey = emotionKey
        self.intensity = intensity
        self.source = source
    }

    var isComplete: Bool { emotionKey != nil && thought != nil && behavior != nil }

    var isBlank: Bool {
        emotionKey == nil
            && (thought ?? "").isEmpty
            && (behavior ?? "").isEmpty
            && behaviorTags.isEmpty
            && associations.isEmpty
    }

    var emotionLabel: String {
        guard let emotionKey else { return "" }
        return EmotionCatalog.emotion(for: emotionKey)?.label ?? emotionKey
    }
}
