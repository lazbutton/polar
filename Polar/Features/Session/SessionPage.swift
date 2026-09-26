import SwiftData
import SwiftUI

/// Préparer ma séance : un résumé factuel depuis la dernière séance, à montrer à ta psy.
struct SessionPage: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \SurveyResponse.date, order: .reverse) private var surveys: [SurveyResponse]

    @State private var presenting = false
    @State private var questionDraft = ""
    @State private var summary: String?

    private var interval: DateInterval {
        let start = SessionFacts.lastSessionDate(logs: logs)
            ?? Calendar.current.date(byAdding: .day, value: -30, to: .now)
            ?? .now
        return DateInterval(start: start, end: .now)
    }

    private var periodLogs: [DayLog] { logs.filter { interval.contains($0.day) } }
    private var facts: [String] { SessionFacts.lines(logs: logs, moments: moments, surveys: surveys, in: interval) }
    private var surveyLines: [String] { SessionFacts.surveyLines(surveys: surveys) }
    private var flaggedMoments: [Moment] {
        moments.filter { $0.forSession && interval.contains($0.createdAt) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                periodHeader
                if preferences.aiEnabled, let summary {
                    block("En quelques mots") { Text(summary).font(.body).foregroundStyle(Palette.ink) }
                }
                block("En un coup d'œil") { LifeChart(logs: periodLogs) }
                if !facts.isEmpty {
                    block("Faits") { linesView(facts) }
                }
                if !surveyLines.isEmpty {
                    block("Questionnaires") { linesView(surveyLines) }
                }
                if !flaggedMoments.isEmpty {
                    block("À en parler") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(flaggedMoments) { moment in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(French.dayTitle(moment.createdAt)) · \(moment.emotionLabel)")
                                        .font(.subheadline).foregroundStyle(Palette.ink)
                                    if let thought = moment.thought, !thought.isEmpty {
                                        Text(thought).font(.caption).foregroundStyle(Palette.inkMuted)
                                    }
                                }
                            }
                        }
                    }
                }
                questionsBlock
                Button("Montrer à ma psy") { presenting = true }
                    .font(.headline)
                    .foregroundStyle(Palette.background)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.ink, in: Capsule())
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Palette.background)
        .navigationTitle("Préparer ma séance")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $presenting) {
            PresentationMode(facts: facts, surveyLines: surveyLines, questions: preferences.sessionQuestions)
        }
        .task {
            #if os(iOS)
            if preferences.aiEnabled {
                summary = await AIService.factualSummary(of: facts)
            }
            #endif
        }
    }

    private var periodHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Depuis le \(interval.start.formatted(.dateTime.day().month(.wide).locale(French.locale)))")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
        }
    }

    private var questionsBlock: some View {
        block("Mes questions") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(preferences.sessionQuestions.enumerated()), id: \.offset) { index, question in
                    HStack {
                        Text(question).foregroundStyle(Palette.ink)
                        Spacer()
                        Button {
                            var copy = preferences.sessionQuestions
                            copy.remove(at: index)
                            preferences.sessionQuestions = copy
                            preferences.save()
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("Ajouter une question", text: $questionDraft)
                    Button("OK") {
                        let word = questionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !word.isEmpty else { return }
                        preferences.sessionQuestions.append(word)
                        preferences.save()
                        questionDraft = ""
                    }
                    .foregroundStyle(Palette.ink)
                }
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func linesView(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Text(line).font(.body).foregroundStyle(Palette.ink)
            }
        }
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Mode présentation : plein écran, gros caractères, bloc par bloc.
private struct PresentationMode: View {
    let facts: [String]
    let surveyLines: [String]
    let questions: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                group("Faits", facts)
                group("Questionnaires", surveyLines)
                group("Mes questions", questions)
            }
            .padding(28)
        }
        .background(Palette.background)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.inkFaint)
                    .padding(20)
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.title2)
                        .foregroundStyle(Palette.ink)
                }
            }
        }
    }
}
