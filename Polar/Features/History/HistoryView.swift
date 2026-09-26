import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @State private var query = ""
    @State private var answer: String?

    var body: some View {
        @Bindable var preferences = preferences
        VStack(alignment: .leading, spacing: 12) {
            Picker("Vue", selection: $preferences.historyShowsCharts) {
                Text("Calendrier").tag(false)
                Text("Courbes").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .onChange(of: preferences.historyShowsCharts) { _, _ in preferences.save() }

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if preferences.historyShowsCharts {
                    ChartsPane()
                } else {
                    CalendarPane()
                }
            } else {
                SearchResults(query: query, moments: moments, logs: logs, answer: answer)
            }
        }
        .padding(.top, 8)
        .background(Palette.background)
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Pour ma psy") { router.push(.forPsy) }
            }
        }
        .searchable(text: $query, prompt: "Chercher dans mes notes")
        .onSubmit(of: .search) { Task { await runSearch() } }
        .onChange(of: query) { _, _ in answer = nil }
    }

    private func runSearch() async {
        let words = query.split(separator: " ")
        guard words.count > 2 else { return }
        if #available(iOS 27, *) {
            answer = await NoteSearch.answer(query: query)
        }
    }
}

struct SearchResults: View {
    var query: String
    var moments: [Moment]
    var logs: [DayLog]
    var answer: String?
    @Environment(Router.self) private var router

    private var foundMoments: [Moment] { NoteSearch.local(query: query, moments: moments) }
    private var foundDays: [DayLog] {
        let folded = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: French.locale)
        guard !folded.isEmpty else { return [] }
        return logs.filter {
            ($0.note ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: French.locale).contains(folded)
        }
    }

    var body: some View {
        List {
            if let answer {
                Text(answer)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .listRowBackground(Palette.surface)
            }
            if foundMoments.isEmpty, foundDays.isEmpty, answer == nil {
                Text("Rien trouvé pour « \(query) ».")
                    .foregroundStyle(Palette.inkMuted)
                    .listRowBackground(Color.clear)
            }
            ForEach(foundMoments) { moment in
                Button {
                    router.present(.moment(moment.persistentModelID))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(French.dayTitle(moment.createdAt)) · \(French.time(moment.createdAt))")
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkMuted)
                        Text(moment.emotionKey == nil ? "Moment" : moment.emotionLabel)
                            .foregroundStyle(Palette.ink)
                        if let thought = moment.thought, !thought.isEmpty {
                            Text(thought).font(.caption).foregroundStyle(Palette.inkMuted).lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
            }
            ForEach(foundDays) { log in
                Button {
                    router.push(.day(log.day))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(French.dayTitle(log.day))
                            .foregroundStyle(Palette.ink)
                        Text(log.note ?? "")
                            .font(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
