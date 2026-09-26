import SwiftUI

@main
struct PolarWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchMomentView()
        }
    }
}

struct WatchMomentView: View {
    @State private var emotion: String?
    @State private var noted = false
    private let emotions = ["calme", "joie", "anxiete", "tristesse", "colere", "epuisement"]

    var body: some View {
        VStack(spacing: 8) {
            if noted {
                Text("C'est noté.")
                    .font(.headline)
            } else if emotion == nil {
                Text("Émotion")
                    .font(.headline)
                ForEach(emotions, id: \.self) { key in
                    Button(EmotionCatalog.emotion(for: key)?.label ?? key) {
                        emotion = key
                    }
                }
            } else {
                Text("Intensité")
                    .font(.headline)
                ForEach([2, 5, 8], id: \.self) { level in
                    Button("\(level)") { save(level) }
                }
            }
        }
    }

    private func save(_ intensity: Int) {
        guard let emotion else { return }
        let moment = WatchMoment(createdAt: .now, emotionKey: emotion, intensity: intensity)
        WatchBridge.shared.activate()
        WatchBridge.shared.send(moment)
        let stored = Moment(emotionKey: emotion, intensity: intensity, source: "watch")
        SharedStore.container.mainContext.insert(stored)
        try? SharedStore.container.mainContext.save()
        noted = true
    }
}
