import Charts
import SwiftUI

struct LifeChart: View {
    var logs: [DayLog]
    var height: CGFloat = 180
    @Binding var selection: Date?

    init(logs: [DayLog], height: CGFloat = 180, selection: Binding<Date?> = .constant(nil)) {
        self.logs = logs
        self.height = height
        self._selection = selection
    }

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
        .chartXSelection(value: $selection)
        .frame(height: height)
        .accessibilityLabel("Humeur haute au-dessus, humeur basse en dessous")
    }
}

struct SleepChart: View {
    var logs: [DayLog]
    @Binding var selection: Date?

    init(logs: [DayLog], selection: Binding<Date?> = .constant(nil)) {
        self.logs = logs
        self._selection = selection
    }

    var body: some View {
        Chart(logs.sorted { $0.day < $1.day }) { log in
            sleepMarks(log)
        }
        .chartYScale(domain: 0.0...1440.0)
        .chartYAxis {
            AxisMarks(values: [0.0, 360.0, 720.0, 1080.0]) { value in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text("\(Int(raw) / 60) h").foregroundStyle(Palette.inkMuted)
                    }
                }
            }
        }
        .chartXSelection(value: $selection)
        .frame(height: 160)
        .accessibilityLabel("Sommeil, du coucher au lever")
    }

    @ChartContentBuilder
    private func sleepMarks(_ log: DayLog) -> some ChartContent {
        if let night = log.resolvedSleepNight() {
            let start = minutes(night.bedtime)
            let end = minutes(night.wake)
            if start <= end {
                bar(log.day, start, end)
            } else {
                bar(log.day, start, 1440.0)
                bar(log.day, 0.0, end)
            }
        } else if let hours = log.resolvedSleepHours {
            BarMark(
                x: .value("Jour", log.day, unit: .day),
                y: .value("Durée", hours * 60)
            )
            .foregroundStyle(Palette.inkMuted)
        }
    }

    private func bar(_ day: Date, _ start: Double, _ end: Double) -> some ChartContent {
        BarMark(
            x: .value("Jour", day, unit: .day),
            yStart: .value("Début", start),
            yEnd: .value("Fin", end)
        )
        .foregroundStyle(Palette.ink.opacity(0.85))
    }

    private func minutes(_ date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}

/// Scores des questionnaires dans le temps, sans libellé de sévérité par défaut.
struct SurveyChart: View {
    var surveys: [SurveyResponse]

    var body: some View {
        if surveys.isEmpty {
            EmptyView()
        } else {
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
