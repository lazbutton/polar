import SwiftData
import SwiftUI

struct ChartsPane: View {
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \SurveyResponse.date) private var surveys: [SurveyResponse]
    @State private var revealed = false
    @State private var selection: Date?

    private var days: Int { preferences.chartSpanDays }
    private var interval: DateInterval {
        let end = Date.now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return DateInterval(start: start, end: end)
    }
    private var periodLogs: [DayLog] { logs.filter { interval.contains($0.day) } }
    private var periodMoments: [Moment] { moments.filter { interval.contains($0.createdAt) } }
    private var periodSurveys: [SurveyResponse] { surveys.filter { interval.contains($0.date) } }

    var body: some View {
        @Bindable var preferences = preferences
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Période", selection: $preferences.chartSpanDays) {
                    Text("30 j").tag(30)
                    Text("90 j").tag(90)
                    Text("1 an").tag(365)
                }
                .pickerStyle(.segmented)
                .onChange(of: preferences.chartSpanDays) { _, _ in preferences.save() }

                if logs.count < 7 {
                    Text("Les courbes se dessinent après une semaine de bilans.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                } else if preferences.discreetMode, !revealed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Courbes masquées. Tes notes continuent.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkMuted)
                        Button("Afficher") { revealed = true }
                            .buttonStyle(PolarPrimaryButton())
                    }
                } else {
                    chartCard("Humeur et énergie", note: Insights.moodLine(periodLogs)) {
                        LifeChart(logs: periodLogs, selection: $selection)
                    }
                    chartCard("Sommeil", note: Insights.sleepLine(periodLogs)) {
                        SleepChart(logs: periodLogs, selection: $selection)
                    }
                    questionnaireCard
                    emotionCard
                    if preferences.trackRhythm {
                        rhythmCard
                    }
                    if preferences.trackFactors {
                        factorCard
                    }
                    if let selection {
                        Text(French.dayTitle(selection))
                            .font(.caption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 80)
        }
        .sensoryFeedback(trigger: selection) { _, _ in
            preferences.hapticsEnabled ? .selection : nil
        }
    }

    private func chartCard<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            content()
            Text(note)
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var questionnaireCard: some View {
        let phq = periodSurveys.last { $0.instrument == "phq9" }
        let asrm = periodSurveys.last { $0.instrument == "asrm" }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Questionnaires")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if phq != nil || asrm != nil {
                Text([phq.map { "PHQ-9 \($0.score)" }, asrm.map { "ASRM \($0.score)" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                SurveyChart(surveys: periodSurveys)
            }
            Button {
                router.present(.weekly)
            } label: {
                HStack {
                    Text("Faire le point")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emotionCard: some View {
        let names = Insights.frequentEmotions(periodMoments, limit: 3).map(\.label)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Émotions")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(names.isEmpty ? "Les émotions notées apparaîtront ici." : names.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var rhythmCard: some View {
        let noted = periodLogs.filter { $0.activityStart != nil || $0.firstContact != nil }.count
        return chartCard("Rythme du jour", note: noted == 0 ? "Rien de noté sur cette période." : "\(noted) jours notés") {
            Text("Premier contact, début d'activité, dîner.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
        }
    }

    private var factorCard: some View {
        var counts: [String: Int] = [:]
        for log in periodLogs {
            for factor in log.factors where factor.count > 0 {
                counts[factor.key, default: 0] += factor.count
            }
        }
        let top = counts.sorted { $0.value > $1.value }.prefix(3).map { FactorCatalog.label(for: $0.key) }
        return chartCard("Facteurs", note: top.isEmpty ? "Rien de noté sur cette période." : top.joined(separator: " · ")) {
            EmptyView()
        }
    }
}
