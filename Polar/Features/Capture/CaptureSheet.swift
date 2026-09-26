import SwiftData
import SwiftUI

struct CaptureSheet: View {
    var momentID: PersistentIdentifier
    var voice: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]

    @State private var showCatalog = false
    @State private var customWord = ""
    @State private var showCustom = false
    @State private var finished = false
    @State private var listening = false
    @State private var speech = SpeechService()

    private var moment: Moment {
        context.model(for: momentID) as! Moment
    }

    var body: some View {
        @Bindable var moment = moment
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                emotionBlock(moment)
                thoughtBlock(moment)
                behaviorBlock(moment)
                Button("Terminé") { finish() }
                    .font(.headline)
                    .foregroundStyle(Palette.background)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.ink, in: Capsule())
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationTitle("Moment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if voice { Task { await dictate(into: moment) } }
        }
        .onDisappear {
            guard !finished, moment.isBlank else { return }
            context.delete(moment)
            try? context.save()
        }
    }

    private func emotionBlock(_ moment: Moment) -> some View {
        @Bindable var moment = moment
        return VStack(alignment: .leading, spacing: 16) {
            Text(listening ? "J'écoute." : "Qu'est-ce que tu ressens ?")
                .font(.title2.weight(.semibold))
            FlowLayout {
                ForEach(visibleKeys, id: \.self) { key in
                    EmotionChip(title: EmotionCatalog.emotion(for: key)?.label ?? key, selected: moment.emotionKey == key) {
                        moment.emotionKey = key
                        if moment.intensity == nil { moment.intensity = 5 }
                    }
                }
                EmotionChip(title: "Plus…", selected: showCatalog) { showCatalog.toggle() }
                EmotionChip(title: "Autre", selected: showCustom) { showCustom.toggle() }
            }
            if showCatalog {
                FlowLayout {
                    ForEach(EmotionCatalog.all) { emotion in
                        EmotionChip(title: emotion.label, selected: moment.emotionKey == emotion.id) {
                            moment.emotionKey = emotion.id
                            if moment.intensity == nil { moment.intensity = 5 }
                        }
                    }
                }
            }
            if showCustom {
                TextField("Un mot à toi", text: $customWord)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onSubmit {
                        let word = customWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !word.isEmpty else { return }
                        moment.emotionKey = word
                        if moment.intensity == nil { moment.intensity = 5 }
                    }
            }
            if moment.emotionKey != nil {
                intensity(moment)
                associations(moment)
            }
        }
    }

    private var visibleKeys: [String] {
        Journal.recentEmotionKeys(from: moments)
    }

    private func intensity(_ moment: Moment) -> some View {
        @Bindable var moment = moment
        let value = moment.intensity ?? 5
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Intensité")
                Spacer()
                Text("\(value)")
                    .font(.title.monospacedDigit())
                    .fontDesign(.rounded)
            }
            Slider(
                value: Binding(
                    get: { Double(moment.intensity ?? 5) },
                    set: { moment.intensity = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(Palette.ink)
            .sensoryFeedback(.selection, trigger: moment.intensity)
            HStack {
                Text("0")
                Spacer()
                Text("10")
            }
            .font(.caption)
            .foregroundStyle(Palette.inkFaint)
        }
    }

    private func associations(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("C'est lié à…")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            FlowLayout {
                ForEach(AssociationCatalog.all) { association in
                    EmotionChip(title: association.label, selected: moment.associations.contains(association.id)) {
                        if moment.associations.contains(association.id) {
                            moment.associations.removeAll { $0 == association.id }
                        } else {
                            moment.associations.append(association.id)
                        }
                    }
                }
            }
        }
    }

    private func thoughtBlock(_ moment: Moment) -> some View {
        @Bindable var moment = moment
        return VStack(alignment: .leading, spacing: 12) {
            Text("Qu'est-ce qui te passe par la tête ?")
                .font(.title2.weight(.semibold))
            TextField("Qu'est-ce qui te passe par la tête ?", text: Binding(
                get: { moment.thought ?? "" },
                set: { moment.thought = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(4...8)
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                ForEach(["Je me dis que…", "J'ai peur que…"], id: \.self) { prompt in
                    EmotionChip(title: prompt, selected: false) {
                        let current = moment.thought ?? ""
                        moment.thought = current.isEmpty ? prompt + " " : current + " " + prompt + " "
                    }
                }
                Spacer()
                Image(systemName: listening ? "mic.fill" : "mic")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Palette.ink)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !listening else { return }
                                listening = true
                                Task { await dictate(into: moment) }
                            }
                            .onEnded { _ in
                                Task {
                                    let text = await speech.stop()
                                    listening = false
                                    await applyTranscript(text, to: moment)
                                }
                            }
                    )
                    .accessibilityLabel("Dicter")
            }
            if Distress.containsSignal(moment.thought ?? "") {
                Button { router.openSafetyPlan() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                        Text("Ton plan de sécurité est là")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    private func behaviorBlock(_ moment: Moment) -> some View {
        @Bindable var moment = moment
        return VStack(alignment: .leading, spacing: 12) {
            Text("Qu'est-ce que tu as fait, ou envie de faire ?")
                .font(.title2.weight(.semibold))
            TextField("Qu'est-ce que tu as fait, ou envie de faire ?", text: Binding(
                get: { moment.behavior ?? "" },
                set: { moment.behavior = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(3...6)
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            FlowLayout {
                ForEach(preferences.behaviorTags, id: \.self) { tag in
                    EmotionChip(title: tag, selected: moment.behaviorTags.contains(tag)) {
                        if moment.behaviorTags.contains(tag) {
                            moment.behaviorTags.removeAll { $0 == tag }
                        } else {
                            moment.behaviorTags.append(tag)
                            if (moment.behavior ?? "").isEmpty { moment.behavior = tag }
                        }
                    }
                }
            }
            Toggle("À en parler avec ma psy", isOn: Binding(
                get: { moment.forSession },
                set: { moment.forSession = $0 }
            ))
            .tint(Palette.ink)
            .font(.subheadline)
        }
    }

    private func finish() {
        finished = true
        let saved = moment
        SpotlightIndex.index(saved)
        Task { await publishHealth(saved) }
        router.pulse()
        ToastCenter.shared.show(saved.isComplete ? "C'est noté." : "À compléter quand tu veux.") {
            context.delete(saved)
            SpotlightIndex.remove(saved)
            try? context.save()
        }
        dismiss()
    }

    private func dictate(into moment: Moment) async {
        listening = true
        try? await speech.start()
    }

    private func applyTranscript(_ text: String, to moment: Moment) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if Distress.containsSignal(trimmed) {
            router.openSupport()
            return
        }
        guard preferences.aiEnabled else {
            moment.thought = trimmed
            moment.source = "voix"
            return
        }
        switch await AIService.makeDraft(from: trimmed) {
        case .draft(let emotion, let intensity, let thought, let behavior):
            if !emotion.isEmpty { moment.emotionKey = emotion }
            moment.intensity = intensity
            moment.thought = thought.isEmpty ? nil : thought
            moment.behavior = behavior.isEmpty ? nil : behavior
            moment.source = "voix"
        case .support:
            router.openSupport()
        case .unavailable:
            moment.thought = trimmed
            moment.source = "voix"
        }
    }

    private func publishHealth(_ moment: Moment) async {
        guard preferences.healthWriteEnabled,
              let key = moment.emotionKey,
              let emotion = EmotionCatalog.emotion(for: key),
              moment.intensity != nil else { return }
        if let id = try? await HealthService.shared.write(moment, emotion: emotion) {
            moment.healthSampleID = id
            try? context.save()
        }
    }
}
