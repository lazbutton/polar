import AppIntents
import SwiftUI
import WidgetKit

struct QuickEmotionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.laz.polar.emotions", provider: EmotionProvider()) { _ in
            EmotionGrid()
        }
        .configurationDisplayName("Noter une émotion")
        .description("Une émotion, à compléter plus tard.")
        .supportedFamilies([.systemMedium])
    }
}

struct EmotionProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmotionEntry { EmotionEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (EmotionEntry) -> Void) {
        completion(EmotionEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EmotionEntry>) -> Void) {
        completion(Timeline(entries: [EmotionEntry(date: .now)], policy: .never))
    }
}

struct EmotionEntry: TimelineEntry {
    var date: Date
}

struct EmotionGrid: View {
    private let emotions: [EmotionOption] = [.calme, .joie, .soulagement, .anxiete, .tristesse, .colere, .irritation, .epuisement]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Polar")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(emotions, id: \.self) { emotion in
                    Button(intent: QuickEmotionIntent(emotion: emotion)) {
                        Text(EmotionCatalog.emotion(for: emotion.rawValue)?.label ?? emotion.rawValue)
                            .font(.caption2)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.white }
    }
}

struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "fr.laz.polar.capture") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Nouveau moment", systemImage: "plus")
            }
        }
        .displayName("Nouveau moment")
    }
}

@main
struct PolarWidgets: WidgetBundle {
    var body: some Widget {
        QuickEmotionWidget()
        CaptureControl()
    }
}
