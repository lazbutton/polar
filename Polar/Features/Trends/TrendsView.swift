import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]

    @State private var days = 30
    @State private var firstMeasure = Measure.sleep
    @State private var secondMeasure = Measure.elevated
    @State private var includeThoughts = false
    @State private var query = ""
    @State private var answer: String?
    @State private var summary: String?
    @State private var shareItem: ShareItem?

    private var interval: DateInterval {
        let end = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    private var periodLogs: [DayLog] { logs.filter { interval.contains($0.day) } }
    private var periodMoments: [Moment] { moments.filter { interval.contains($0.createdAt) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Tendances")
                    .font(.largeTitle.weight(.semibold))
                Picker("Période", selection: $days) {
                    Text("30 jours").tag(30)
                    Text("90 jours").tag(90)
                    Text("1 an").tag(365)
                }
                .pickerStyle(.segmented)
                LifeChart(logs: periodLogs)
                SleepChart(logs: periodLogs)
                facts
                emotions
                compare
                search
                summaryBlock
                export
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .background(Palette.background)
        .sheet(item: $shareItem) { item in
            ShareLink(item: item.url) { Text("Partager") }
                .padding()
        }
    }

    private var facts: some View {
        let lines = Insights.lines(logs: periodLogs, moments: periodMoments, rules: preferences.alertRules, in: interval)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Constats")
                .font(.headline)
            if lines.isEmpty {
                Text("Pas encore assez de notes.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            } else {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.body)
                }
            }
        }
    }

    private var emotions: some View {
        let rows = Insights.frequentEmotions(periodMoments)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Émotions")
                .font(.headline)
            ForEach(rows, id: \.label) { row in
                let hours = Set(row.hours).sorted().map { "\($0) h" }.joined(separator: ", ")
                Text("\(row.label) · \(row.count)\(hours.isEmpty ? "" : " · \(hours)")")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private var compare: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparer")
                .font(.headline)
            HStack {
                Picker("Première mesure", selection: $firstMeasure) {
                    ForEach(Measure.allCases) { Text($0.label).tag($0) }
                }
                Picker("Deuxième mesure", selection: $secondMeasure) {
                    ForEach(Measure.allCases) { Text($0.label).tag($0) }
                }
            }
            .pickerStyle(.menu)
            ComparisonChart(logs: periodLogs, first: firstMeasure, second: secondMeasure)
            Text("Les deux mesures sont ramenées à la même hauteur.")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rechercher")
                .font(.headline)
            TextField("Un mot, ou une question", text: $query)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit { Task { await runSearch() } }
            let found = NoteSearch.local(query: query, moments: moments)
            ForEach(found.prefix(8)) { moment in
                Text("\(French.dayTitle(moment.createdAt)) · \(moment.emotionLabel)")
                    .font(.subheadline)
            }
            if let answer {
                Text(answer)
                    .font(.body)
            }
        }
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Résumé de la semaine") {
                Task {
                    let week = DateInterval(start: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now, end: .now)
                    let facts = Insights.lines(
                        logs: logs.filter { week.contains($0.day) },
                        moments: moments.filter { week.contains($0.createdAt) },
                        rules: preferences.alertRules,
                        in: week
                    )
                    summary = await AIService.factualSummary(of: facts)
                }
            }
            .foregroundStyle(Palette.ink)
            if let summary {
                Text(summary)
                    .font(.body)
            }
        }
    }

    private var export: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Inclure les pensées", isOn: $includeThoughts)
                .tint(Palette.ink)
            Button("Rapport PDF du mois") { exportPDF() }
            Button("CSV") { exportCSV() }
            Button("Sauvegarde JSON") { exportJSON() }
        }
        .font(.headline)
        .foregroundStyle(Palette.ink)
    }

    private func runSearch() async {
        if #available(iOS 27, *), preferences.aiEnabled, query.split(separator: " ").count > 2 {
            answer = await NoteSearch.answer(query: query)
        } else {
            answer = nil
        }
    }

    private func exportPDF() {
        let facts = Insights.lines(logs: periodLogs, moments: periodMoments, rules: preferences.alertRules, in: interval)
        let data = PDFReport.make(month: .now, logs: logs, moments: moments, includeThoughts: includeThoughts, facts: facts)
        if let url = writeTemp(data: data, name: "Polar.pdf") { shareItem = ShareItem(url: url) }
    }

    private func exportCSV() {
        guard let text = try? CSVExport.make(in: context) else { return }
        if let url = writeTemp(data: Data(text.utf8), name: "Polar.csv") { shareItem = ShareItem(url: url) }
    }

    private func exportJSON() {
        guard let data = try? Backup.make(in: context) else { return }
        if let url = writeTemp(data: data, name: "Polar.json") { shareItem = ShareItem(url: url) }
    }

    private func writeTemp(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ComparisonChart: View {
    var logs: [DayLog]
    var first: Measure
    var second: Measure

    var body: some View {
        Chart {
            ForEach(logs) { log in
                if let value = normalized(first, log) {
                    LineMark(x: .value("Jour", log.day, unit: .day), y: .value(first.label, value))
                        .foregroundStyle(Palette.ink)
                }
                if let value = normalized(second, log) {
                    LineMark(x: .value("Jour", log.day, unit: .day), y: .value(second.label, value))
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .frame(height: 160)
        .accessibilityLabel("\(first.label) et \(second.label)")
    }

    private func normalized(_ measure: Measure, _ log: DayLog) -> Double? {
        guard let value = measure.value(in: log) else { return nil }
        let values = logs.compactMap { measure.value(in: $0) }
        guard let max = values.max(), max > 0 else { return 0 }
        return value / max
    }
}
