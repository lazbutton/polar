import Foundation
import SwiftData
import SwiftUI
import UIKit

enum CSVExport {
    @MainActor
    static func make(in context: ModelContext) throws -> String {
        var rows = ["type,date,emotion,intensite,pensee,comportement,humeur_basse,humeur_haute,irritabilite,anxiete,sommeil,note"]
        let moments = try context.fetch(FetchDescriptor<Moment>(sortBy: [SortDescriptor(\.createdAt)]))
        for moment in moments {
            rows.append([
                "moment",
                iso(moment.createdAt),
                moment.emotionLabel,
                moment.intensity.map(String.init) ?? "",
                moment.thought ?? "",
                moment.behavior ?? "",
                "", "", "", "", "", "",
            ].map(csv).joined(separator: ","))
        }
        let logs = try context.fetch(FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.day)]))
        for log in logs {
            rows.append([
                "bilan",
                iso(log.day),
                "", "", "", "",
                String(log.depressed),
                String(log.elevated),
                String(log.irritability),
                String(log.anxiety),
                log.resolvedSleepHours.map { String($0) } ?? "",
                log.note ?? "",
            ].map(csv).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func csv(_ field: String) -> String {
        "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

enum PDFReport {
    @MainActor
    static func make(
        title: String,
        logs: [DayLog],
        moments: [Moment],
        includeThoughts: Bool,
        facts: [String]
    ) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let monthLogs = logs
        let monthMoments = moments
        return renderer.pdfData { context in
            draw(page: page, in: context) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Polar")
                        .font(.largeTitle.weight(.semibold))
                    Text(title)
                        .font(.title2)
                        .foregroundStyle(Palette.inkMuted)
                    LifeChart(logs: monthLogs, height: 220)
                    ForEach(facts, id: \.self) { fact in
                        Text(fact)
                            .font(.body)
                    }
                }
                .padding(32)
                .frame(width: 595, height: 842, alignment: .topLeading)
                .background(Color.white)
            }
            draw(page: page, in: context) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Jour par jour")
                        .font(.title2.weight(.semibold))
                    ForEach(monthLogs.sorted { $0.day < $1.day }) { log in
                        HStack {
                            Text(log.day.formatted(.dateTime.day().month(.abbreviated).locale(French.locale)))
                                .frame(width: 70, alignment: .leading)
                            Text("B \(log.depressed)  H \(log.elevated)  I \(log.irritability)  A \(log.anxiety)")
                            Spacer()
                            Text(log.resolvedSleepHours.map(French.sleep) ?? "")
                                .foregroundStyle(Palette.inkMuted)
                        }
                        .font(.caption)
                    }
                }
                .padding(32)
                .frame(width: 595, height: 842, alignment: .topLeading)
                .background(Color.white)
            }
            if includeThoughts {
                draw(page: page, in: context) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Moments")
                            .font(.title2.weight(.semibold))
                        ForEach(monthMoments.sorted { $0.createdAt < $1.createdAt }) { moment in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(French.time(moment.createdAt))  \(moment.emotionLabel)")
                                    .font(.headline)
                                if let thought = moment.thought, !thought.isEmpty {
                                    Text(thought)
                                        .font(.body)
                                }
                            }
                        }
                    }
                    .padding(32)
                    .frame(width: 595, height: 842, alignment: .topLeading)
                    .background(Color.white)
                }
            }
        }
    }

    @MainActor
    private static func draw(page: CGRect, in context: UIGraphicsPDFRendererContext, @ViewBuilder content: () -> some View) {
        context.beginPage()
        let renderer = ImageRenderer(content: content())
        renderer.scale = 2
        renderer.uiImage?.draw(in: page)
    }
}
