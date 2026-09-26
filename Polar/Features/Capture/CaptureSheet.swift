import SwiftData
import SwiftUI

struct CaptureSheet: View {
    var momentID: PersistentIdentifier?
    var voice: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]

    @State private var localID: PersistentIdentifier?
    @State private var committed = false
    @State private var removed = false
    @State private var showCatalog = false
    @State private var customWord = ""
    @State private var showCustom = false
    @State private var listening = false
    @State private var speech = SpeechService()
    @State private var showLinks = false
    @State private var editingTags = false
    @State private var newTag = ""
    @State private var when = Date.now
    @State private var showWhen = false

    private var resolvedID: PersistentIdentifier? { momentID ?? localID }

    private var moment: Moment? {
        guard !removed, let resolvedID else { return nil }
        if let found = moments.first(where: { $0.persistentModelID == resolvedID }) {
            return found
        }
        return context.model(for: resolvedID) as? Moment
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if showWhen {
                    DatePicker("Quand", selection: whenBinding, displayedComponents: [.date, .hourAndMinute])
                }
                emotionBlock
                thoughtBlock
                behaviorBlock
                Toggle("À en parler avec ma psy", isOn: forSession)
                    .tint(Palette.ink)
                linksBlock
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(title) { showWhen.toggle() }
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { dismiss() }
            }
        }
        .onAppear {
            if let moment { when = moment.createdAt }
            if voice {
                _ = ensure()
                Task { await beginDictation() }
            }
            router.captureVoice = false
        }
        .onDisappear { close() }
    }

    private var title: String {
        let today = Date.now.logicalDay(startHour: preferences.startHour)
        let logical = when.logicalDay(startHour: preferences.startHour)
        let day = Calendar.current.isDate(logical, inSameDayAs: today) ? "Aujourd'hui" : French.shortDay(when)
        return "\(day) · \(French.time(when))"
    }

    private var whenBinding: Binding<Date> {
        Binding(
            get: { moment?.createdAt ?? when },
            set: { value in
                when = value
                ensure().createdAt = value
            }
        )
    }

    private var forSession: Binding<Bool> {
        Binding(
            get: { moment?.forSession ?? false },
            set: { ensure().forSession = $0 }
        )
    }

    private var emotionBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(listening ? "J'écoute." : "Émotion")
                .font(.title2.weight(.semibold))
            FlowLayout {
                ForEach(visibleKeys, id: \.self) { key in
                    EmotionChip(title: EmotionCatalog.emotion(for: key)?.label ?? key, selected: moment?.emotionKey == key) {
                        let moment = ensure()
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
                        EmotionChip(title: emotion.label, selected: moment?.emotionKey == emotion.id) {
                            let moment = ensure()
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
                        let moment = ensure()
                        moment.emotionKey = word
                        if moment.intensity == nil { moment.intensity = 5 }
                    }
            }
            if moment?.emotionKey != nil {
                intensity
            }
        }
    }

    private var visibleKeys: [String] { Journal.recentEmotionKeys(from: moments) }

    private var intensity: some View {
        let value = moment?.intensity ?? 5
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
                    get: { Double(moment?.intensity ?? 5) },
                    set: { ensure().intensity = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(Palette.ink)
            .sensoryFeedback(trigger: moment?.intensity) { _, _ in
                preferences.hapticsEnabled ? .selection : nil
            }
            HStack {
                Text("0")
                Spacer()
                Text("10")
            }
            .font(.caption)
            .foregroundStyle(Palette.inkFaint)
        }
    }

    private var linksBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("C'est lié à…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                if !showLinks {
                    Button("Ajouter") { showLinks = true }
                        .foregroundStyle(Palette.ink)
                }
            }
            if showLinks || !(moment?.associations.isEmpty ?? true) {
                FlowLayout {
                    ForEach(AssociationCatalog.all) { association in
                        EmotionChip(title: association.label, selected: moment?.associations.contains(association.id) == true) {
                            let moment = ensure()
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
    }

    private var thoughtBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pensée")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    toggleDictation()
                } label: {
                    Label("Dicter", systemImage: listening ? "mic.fill" : "mic")
                }
                .foregroundStyle(Palette.ink)
                .accessibilityLabel("Dicter")
            }
            TextField("Qu'est-ce qui te passe par la tête ?", text: thoughtBinding, axis: .vertical)
                .lineLimit(4...8)
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                ForEach(["Je me dis que…", "J'ai peur que…"], id: \.self) { prompt in
                    EmotionChip(title: prompt, selected: false) {
                        let moment = ensure()
                        let current = moment.thought ?? ""
                        moment.thought = current.isEmpty ? prompt + " " : current + " " + prompt + " "
                    }
                }
            }
            if Distress.containsSignal(moment?.thought ?? "") {
                Button { openSafety() } label: {
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
            }
        }
    }

    private var thoughtBinding: Binding<String> {
        Binding(
            get: { moment?.thought ?? "" },
            set: { value in
                if value.isEmpty, moment == nil { return }
                ensure().thought = value.isEmpty ? nil : value
            }
        )
    }

    private var behaviorBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comportement")
                .font(.title2.weight(.semibold))
            TextField("Qu'est-ce que tu as fait, ou envie de faire ?", text: behaviorBinding, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            FlowLayout {
                ForEach(preferences.behaviorTags, id: \.self) { tag in
                    EmotionChip(title: tag, selected: moment?.behaviorTags.contains(tag) == true) {
                        let moment = ensure()
                        if moment.behaviorTags.contains(tag) {
                            moment.behaviorTags.removeAll { $0 == tag }
                        } else {
                            moment.behaviorTags.append(tag)
                            if (moment.behavior ?? "").isEmpty { moment.behavior = tag }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Modifier") { editingTags.toggle() }
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
            }
            if editingTags {
                HStack {
                    TextField("Nouvelle puce", text: $newTag)
                    Button("OK") {
                        let word = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !word.isEmpty else { return }
                        if !preferences.behaviorTags.contains(word) {
                            preferences.behaviorTags.append(word)
                            preferences.save()
                        }
                        newTag = ""
                    }
                }
                ForEach(preferences.behaviorTags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button {
                            preferences.behaviorTags.removeAll { $0 == tag }
                            preferences.save()
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var behaviorBinding: Binding<String> {
        Binding(
            get: { moment?.behavior ?? "" },
            set: { value in
                if value.isEmpty, moment == nil { return }
                ensure().behavior = value.isEmpty ? nil : value
            }
        )
    }

    @discardableResult
    private func ensure() -> Moment {
        if let moment {
            moment.createdAt = when
            return moment
        }
        let created = Moment(source: voice ? "voix" : "app")
        created.createdAt = when
        context.insert(created)
        localID = created.persistentModelID
        try? context.save()
        return created
    }

    private func toggleDictation() {
        if listening {
            Task {
                let text = await speech.stop()
                listening = false
                await applyTranscript(text, to: ensure())
            }
        } else {
            Task { await beginDictation() }
        }
    }

    private func beginDictation() async {
        do {
            try await speech.start()
            listening = true
        } catch {
            listening = false
        }
    }

    private func close() {
        guard !committed else { return }
        if listening {
            Task {
                let text = await speech.stop()
                listening = false
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    await applyTranscript(trimmed, to: ensure())
                }
                if !committed { commit() }
            }
        } else {
            commit()
        }
    }

    private func commit() {
        guard !committed else { return }
        committed = true
        guard let moment else { return }
        if moment.isBlank {
            removed = true
            context.delete(moment)
            try? context.save()
            return
        }
        SpotlightIndex.index(moment)
        try? context.save()
        router.pulse()
        let saved = moment
        ToastCenter.shared.show(saved.isComplete ? "C'est noté." : "À compléter quand tu veux.") {
            context.delete(saved)
            SpotlightIndex.remove(saved)
            try? context.save()
        }
        Task { await publishHealth(saved) }
    }

    private func openSafety() {
        _ = ensure()
        try? context.save()
        committed = true
        router.openFromOutside(.safetyPlan)
    }

    private func applyTranscript(_ text: String, to moment: Moment) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if Distress.containsSignal(trimmed) {
            moment.thought = trimmed
            openSafety()
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
            moment.thought = trimmed
            openSafety()
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
