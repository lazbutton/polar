import SwiftData
import SwiftUI

struct ForPsyPage: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \SurveyResponse.date, order: .reverse) private var surveys: [SurveyResponse]
    @Query(sort: \TherapySession.date) private var sessions: [TherapySession]

    @State private var wholeMonth = false
    @State private var questionDraft = ""
    @State private var summary: String?
    @State private var nextDate = Date.now
    @State private var nextReady = false
    @State private var shareItem: ShareFile?

    private var upcoming: TherapySession? { SessionFacts.nextSession(in: sessions) }

    private var interval: DateInterval {
        if wholeMonth {
            let calendar = Calendar.current
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? .now
            return DateInterval(start: start, end: end)
        }
        let start = SessionFacts.lastSessionDate(logs: logs, sessions: sessions)
            ?? Calendar.current.date(byAdding: .day, value: -30, to: .now)
            ?? .now
        return DateInterval(start: start, end: .now.addingTimeInterval(60))
    }

    private var periodLogs: [DayLog] { logs.filter { interval.contains($0.day) } }
    private var periodMoments: [Moment] { moments.filter { interval.contains($0.createdAt) } }
    private var facts: [String] { SessionFacts.lines(logs: logs, moments: moments, surveys: surveys, in: interval) }
    private var surveyLines: [String] { SessionFacts.surveyLines(surveys: surveys.filter { interval.contains($0.date) }) }
    private var flagged: [Moment] { moments.filter { $0.forSession && interval.contains($0.createdAt) } }

    private var questions: [String] {
        upcoming?.questions ?? preferences.sessionQuestions
    }

    private var hasContent: Bool {
        !periodLogs.isEmpty || !flagged.isEmpty || !surveyLines.isEmpty || !questions.isEmpty
    }

    var body: some View {
        @Bindable var preferences = preferences
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !hasContent {
                    Text("Rien à montrer pour l'instant.")
                        .foregroundStyle(Palette.inkMuted)
                    questionsBlock
                } else {
                    if preferences.aiEnabled, let summary {
                        block("En quelques mots") { Text(summary).foregroundStyle(Palette.ink) }
                    }
                    LifeChart(logs: periodLogs)
                    if !facts.isEmpty { block("Faits") { lines(facts) } }
                    if !surveyLines.isEmpty { block("Questionnaires") { lines(surveyLines) } }
                    talkBlock
                    questionsBlock
                    Toggle("Inclure mes pensées dans le PDF", isOn: $preferences.includeThoughtsInPDF)
                        .tint(Palette.ink)
                        .onChange(of: preferences.includeThoughtsInPDF) { _, _ in preferences.save() }
                    HStack(spacing: 12) {
                        Button("Montrer") { show() }
                            .buttonStyle(PolarPrimaryButton())
                        Button("Partager le PDF") { share() }
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Palette.surface, in: Capsule())
                    }
                    Button("Séance faite aujourd'hui") { markDone() }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Palette.background)
        .navigationTitle("Pour ma psy")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shareItem) { item in
            ShareLink(item: item.url) { Text("Partager le PDF") }
                .padding()
        }
        .task {
            if let upcoming { nextDate = upcoming.date }
            nextReady = true
            await loadSummary()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(wholeMonth
                     ? "Mois de \(French.monthName(.now))"
                     : "Depuis le \(interval.start.formatted(.dateTime.day().month(.wide).locale(French.locale)))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Button("Modifier") { wholeMonth.toggle() }
                    .foregroundStyle(Palette.ink)
            }
            if nextReady {
                DatePicker(
                    "Prochaine séance",
                    selection: $nextDate,
                    displayedComponents: .date
                )
                .onChange(of: nextDate) { _, date in setNext(date) }
            }
        }
    }

    private var talkBlock: some View {
        block("À en parler") {
            if flagged.isEmpty {
                Text("Aucun moment marqué depuis la dernière séance.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            } else {
                List {
                    ForEach(flagged) { moment in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(French.shortDay(moment.createdAt)) · \(French.time(moment.createdAt)) · \(moment.emotionLabel)")
                                .foregroundStyle(Palette.ink)
                            if let thought = moment.thought, !thought.isEmpty {
                                Text(thought).font(.caption).foregroundStyle(Palette.inkMuted)
                            }
                        }
                        .swipeActions {
                            Button("Retirer") {
                                moment.forSession = false
                                try? context.save()
                            }
                        }
                        .listRowBackground(Palette.surface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(flagged.count) * 64)
            }
        }
    }

    private var questionsBlock: some View {
        block("Mes questions") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    HStack {
                        Text(question)
                        Spacer()
                        Button {
                            var copy = questions
                            copy.remove(at: index)
                            store(copy)
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("Ajouter une question", text: $questionDraft)
                    Button("OK") { addQuestion() }
                        .foregroundStyle(Palette.ink)
                }
            }
        }
    }

    private func lines(_ rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { Text($0) }
        }
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func store(_ values: [String]) {
        if let upcoming {
            upcoming.questions = values
            try? context.save()
        } else {
            preferences.sessionQuestions = values
            preferences.save()
        }
    }

    private func addQuestion() {
        let word = questionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        store(questions + [word])
        questionDraft = ""
    }

    private func setNext(_ date: Date) {
        if let upcoming {
            upcoming.date = date
            if upcoming.questions.isEmpty, !preferences.sessionQuestions.isEmpty {
                upcoming.questions = preferences.sessionQuestions
                preferences.sessionQuestions = []
                preferences.save()
            }
        } else {
            let session = TherapySession(date: date, done: false, questions: preferences.sessionQuestions)
            context.insert(session)
            preferences.sessionQuestions = []
            preferences.save()
        }
        try? context.save()
    }

    private func markDone() {
        let prepared = questions
        if let upcoming {
            upcoming.date = .now
            upcoming.done = true
            upcoming.questions = prepared
        } else {
            context.insert(TherapySession(date: .now, done: true, questions: prepared))
        }
        preferences.sessionQuestions = []
        preferences.save()
        if let log = try? DayLog.findOrCreate(startHour: preferences.startHour, in: context) {
            log.therapySession = true
        }
        try? context.save()
        ToastCenter.shared.show("Séance notée.")
    }

    private func show() {
        router.slides = [
            PsyBlock(title: "Faits", lines: facts),
            PsyBlock(title: "Questionnaires", lines: surveyLines),
            PsyBlock(title: "Mes questions", lines: questions),
        ].filter { !$0.lines.isEmpty }
        router.isPresenting = true
    }

    private func share() {
        let data = PDFReport.make(
            title: wholeMonth ? French.monthTitle(.now) : "Depuis le \(French.shortDay(interval.start))",
            logs: periodLogs,
            moments: periodMoments,
            includeThoughts: preferences.includeThoughtsInPDF,
            facts: facts
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Pour-ma-psy.pdf")
        try? data.write(to: url)
        shareItem = ShareFile(url: url)
    }

    private func loadSummary() async {
        guard preferences.aiEnabled else { return }
        summary = await AIService.factualSummary(of: facts)
    }
}

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}
