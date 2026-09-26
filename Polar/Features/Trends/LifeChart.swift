import Charts
import SwiftUI

struct LifeChart: View {
    var logs: [DayLog]
    var height: CGFloat = 180

    var body: some View {
        Chart(logs.sorted { $0.day < $1.day }) { log in
            BarMark(
                x: .value("Jour", log.day, unit: .day),
                y: .value("Humeur haute", log.elevated)
            )
            .foregroundStyle(Palette.elevated)
            BarMark(
                x: .value("Jour", log.day, unit: .day),
                y: .value("Humeur basse", -log.depressed)
            )
            .foregroundStyle(Palette.depressed)
        }
        .chartYScale(domain: -3...3)
        .chartYAxis {
            AxisMarks(values: [-3, 0, 3]) { value in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text(number < 0 ? "\(abs(number))" : "\(number)")
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(logs.count / 6, 1))) { _ in
                AxisValueLabel(format: .dateTime.day().locale(French.locale))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Humeur haute au-dessus, humeur basse en dessous")
    }
}

struct SleepChart: View {
    var logs: [DayLog]

    var body: some View {
        Chart(logs.sorted { $0.day < $1.day }) { log in
            if let hours = log.resolvedSleepHours {
                LineMark(
                    x: .value("Jour", log.day, unit: .day),
                    y: .value("Sommeil", hours)
                )
                .foregroundStyle(Palette.ink)
            }
            if log.intakes?.contains(where: { $0.taken == false }) == true {
                PointMark(
                    x: .value("Jour", log.day, unit: .day),
                    y: .value("Repère", log.resolvedSleepHours ?? 0)
                )
                .foregroundStyle(Palette.inkMuted)
                .symbolSize(40)
            }
        }
        .frame(height: 140)
        .accessibilityLabel("Sommeil")
    }
}

/// Scores des questionnaires dans le temps, sans libellé de sévérité par défaut.
struct SurveyChart: View {
    var surveys: [SurveyResponse]

    var body: some View {
        if surveys.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Questionnaires")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Chart(surveys.sorted { $0.date < $1.date }) { survey in
                    LineMark(
                        x: .value("Jour", survey.date, unit: .day),
                        y: .value("Score", survey.score)
                    )
                    .foregroundStyle(by: .value("Questionnaire", survey.instrument.uppercased()))
                    PointMark(
                        x: .value("Jour", survey.date, unit: .day),
                        y: .value("Score", survey.score)
                    )
                    .foregroundStyle(by: .value("Questionnaire", survey.instrument.uppercased()))
                }
                .chartForegroundStyleScale([
                    "PHQ9": Palette.depressed,
                    "ASRM": Palette.elevated,
                    "GAD7": Palette.anxiety,
                ])
                .frame(height: 140)
                .accessibilityLabel("Scores des questionnaires")
            }
        }
    }
}

enum Measure: String, CaseIterable, Identifiable {
    case sleep, elevated, depressed, irritability, anxiety, weight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sleep: "Sommeil"
        case .elevated: "Humeur haute"
        case .depressed: "Humeur basse"
        case .irritability: "Irritabilité"
        case .anxiety: "Anxiété"
        case .weight: "Poids"
        }
    }

    func value(in log: DayLog) -> Double? {
        switch self {
        case .sleep: log.resolvedSleepHours
        case .elevated: Double(log.elevated)
        case .depressed: Double(log.depressed)
        case .irritability: Double(log.irritability)
        case .anxiety: Double(log.anxiety)
        case .weight: log.weightKg
        }
    }
}
