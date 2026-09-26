import SwiftData
import SwiftUI

/// Point de la semaine : PHQ-9, ASRM, puis GAD-7 en option. Une question par écran.
struct WeeklyCheckPage: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router

    @State private var step = 0
    @State private var answers: [String: [Int]] = [:]
    @State private var finished = false

    private var questionnaires: [Questionnaire] {
        Questionnaire.weekly(includeGAD7: preferences.includeGAD7)
    }

    /// Séquence à plat : (questionnaire, index de la question).
    private var steps: [(Questionnaire, Int)] {
        questionnaires.flatMap { q in q.questions.indices.map { (q, $0) } }
    }

    var body: some View {
        Group {
            if finished {
                summary
            } else if step < steps.count {
                question(steps[step].0, index: steps[step].1)
            }
        }
        .background(Palette.background)
        .navigationTitle("Point de la semaine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { prime() }
    }

    private func question(_ questionnaire: Questionnaire, index: Int) -> some View {
        let question = questionnaire.questions[index]
        return VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(step + 1), total: Double(steps.count))
                .tint(Palette.ink)
            Text("\(step + 1) / \(steps.count)")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
            if let prompt = questionnaire.prompt {
                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            } else {
                Text(questionnaire.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            }
            Text(question.text)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { value, label in
                    let selected = answers[questionnaire.id]?[index] == value
                    Button {
                        answer(questionnaire, index: index, value: value)
                    } label: {
                        Text(label)
                            .font(.body)
                            .foregroundStyle(selected ? Palette.background : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .padding(.horizontal, 16)
                            .background(selected ? Palette.ink : Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .sensoryFeedback(.selection, trigger: step)
        .gesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                if value.translation.width > 60 { back() }
            }
        )
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("C'est noté.")
                .font(.title.weight(.semibold))
                .foregroundStyle(Palette.ink)
            ForEach(questionnaires) { questionnaire in
                if let given = answers[questionnaire.id] {
                    let score = questionnaire.score(given)
                    Text("\(questionnaire.title) : \(score) sur \(questionnaire.maxScore)")
                        .font(.title3.monospacedDigit())
                        .fontDesign(.rounded)
                        .foregroundStyle(Palette.ink)
                }
            }
            Text("Les repères publiés figurent dans le rapport pour ta psy.")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
            Spacer()
        }
        .padding(20)
    }

    private func prime() {
        for questionnaire in questionnaires where answers[questionnaire.id] == nil {
            answers[questionnaire.id] = Array(repeating: -1, count: questionnaire.questions.count)
        }
    }

    private func answer(_ questionnaire: Questionnaire, index: Int, value: Int) {
        answers[questionnaire.id, default: Array(repeating: -1, count: questionnaire.questions.count)][index] = value
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            advance()
        }
    }

    private func advance() {
        if step + 1 < steps.count {
            step += 1
        } else {
            complete()
        }
    }

    private func back() {
        if step > 0 { step -= 1 }
    }

    private func complete() {
        var item9Positive = false
        for questionnaire in questionnaires {
            guard let given = answers[questionnaire.id], !given.contains(-1) else { continue }
            let response = SurveyResponse(instrument: questionnaire.id, answers: given)
            context.insert(response)
            if response.phq9Item9Positive { item9Positive = true }
        }
        try? context.save()
        finished = true
        if item9Positive {
            ToastCenter.shared.show("Merci de l'avoir dit. Ton plan est là.")
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                router.openSafetyPlan()
            }
        }
    }
}
