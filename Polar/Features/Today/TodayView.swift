import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \DayLog.day, order: .reverse) private var logs: [DayLog]
    @Query private var plans: [CarePlan]
    @State private var notedKey = ""

    private var today: Date { Date.now.logicalDay(startHour: preferences.startHour) }
    private var todaysMoments: [Moment] {
        Journal.moments(moments, on: .now, startHour: preferences.startHour)
    }
    private var log: DayLog? {
        logs.first { Calendar.current.isDate($0.day, inSameDayAs: today) }
    }
    private var plan: CarePlan? { plans.first }
    private var hits: [AlertHit] {
        AlertEngine.hits(rules: preferences.alertRules, logs: logs, startHour: preferences.startHour)
    }
    private var eveningPending: Bool { preferences.isPastEveningReminder() && log == nil }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 4)
            CoherenceStage(
                asleep: preferences.isNight() || colorSchemeNight,
                pulse: router.pulseToken
            )
            .padding(.top, 0)
            .padding(.horizontal, 20)
            journal
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(French.dayTitle(.now))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Button { router.openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Palette.ink)
            }
            .accessibilityLabel("Réglages")
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    private var colorSchemeNight: Bool { colorScheme == .dark && preferences.appearance != .alwaysLight }

    private var journal: some View {
        List {
            if let hit = hits.first {
                alertCard(hit)
                    .journalRow(top: 16, bottom: 6)
            }
            dayCard
                .journalRow(top: 12, bottom: 4)
            Text("Moments")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .journalRow(top: 12, bottom: 4)
            composer
                .journalRow(top: 0, bottom: 8)
            if todaysMoments.isEmpty {
                Text("Rien de noté aujourd'hui.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .journalRow(top: 0, bottom: 8)
            } else {
                ForEach(todaysMoments) { moment in
                    momentRow(moment)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 8)
        .contentMargins(.top, 8, for: .scrollContent)
        .contentMargins(.bottom, 72, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Palette.surface)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var dayCard: some View {
        Button { router.openDayLog(on: .now) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Bilan du jour")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    if let hours = log?.sleepHours {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Sommeil")
                                .font(.subheadline)
                                .foregroundStyle(Palette.inkMuted)
                            Text(French.sleep(hours))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.inkFaint)
                }
                if let log {
                    if log.sleepHours == nil {
                        Text("Sommeil non noté")
                            .font(.caption)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        if preferences.trackDepressed {
                            GlanceGauge(title: "Humeur basse", level: log.depressed, color: Palette.depressed)
                        }
                        if preferences.trackElevated {
                            GlanceGauge(title: "Humeur haute", level: log.elevated, color: Palette.elevated)
                        }
                        if preferences.trackIrritability {
                            GlanceGauge(title: "Irritabilité", level: log.irritability, color: Palette.irritability)
                        }
                        if preferences.trackAnxiety {
                            GlanceGauge(title: "Anxiété", level: log.anxiety, color: Palette.anxiety)
                        }
                    }
                } else {
                    Text("Sommeil, humeur, irritabilité et anxiété.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(eveningPending ? Palette.ink : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bilan du jour")
        .accessibilityValue(glanceAccess)
        .accessibilityHint("Ouvre le bilan")
        .accessibilityAddTraits(.isButton)
    }

    private var glanceAccess: String {
        guard let log else { return "Pas encore fait" }
        var parts: [String] = []
        if let hours = log.sleepHours {
            parts.append("Sommeil \(French.sleep(hours))")
        }
        if preferences.trackDepressed { parts.append("Humeur basse \(DayLevel.word(log.depressed))") }
        if preferences.trackElevated { parts.append("Humeur haute \(DayLevel.word(log.elevated))") }
        if preferences.trackIrritability { parts.append("Irritabilité \(DayLevel.word(log.irritability))") }
        if preferences.trackAnxiety { parts.append("Anxiété \(DayLevel.word(log.anxiety))") }
        return parts.joined(separator: ", ")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Un mot suffit.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickEmotions, id: \.id) { emotion in
                        Button {
                            note(emotion.id)
                        } label: {
                            Text(emotion.label)
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Palette.background, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 20) {
                Button("Écrire") { router.openCapture() }
                Button("Dicter") { router.openCapture(voice: true) }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.ink)
            .frame(minHeight: 44, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: notedKey)
    }

    private var quickEmotions: [Emotion] {
        Journal.recentEmotionKeys(from: moments).compactMap(EmotionCatalog.emotion(for:))
    }

    private func note(_ key: String) {
        let moment = Moment(emotionKey: key, source: "app")
        notedKey = key
        context.insert(moment)
        try? context.save()
        SpotlightIndex.index(moment)
        router.pulse()
        ToastCenter.shared.show("À compléter quand tu veux.") {
            context.delete(moment)
            SpotlightIndex.remove(moment)
            try? context.save()
        }
    }

    private func momentRow(_ moment: Moment) -> some View {
        Button {
            router.openMoment(moment.persistentModelID)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(French.time(moment.createdAt))
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                        .monospacedDigit()
                    Text(moment.emotionKey == nil ? "À compléter" : moment.emotionLabel)
                        .font(.subheadline)
                        .foregroundStyle(moment.emotionKey == nil ? Palette.inkMuted : Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let intensity = moment.intensity {
                        Text("\(intensity)")
                            .font(.subheadline.weight(.medium))
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                }
                if let thought = moment.thought, !thought.isEmpty {
                    Text(thought)
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint(moment.isComplete ? "Ouvre ce moment" : "À compléter")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(moment) } label: {
                Label("Supprimer", systemImage: "trash")
            }
            .tint(Palette.ink)
        }
        .swipeActions(edge: .leading) {
            Button {
                router.openMoment(moment.persistentModelID)
            } label: {
                Label("Compléter", systemImage: "square.and.pencil")
            }
            .tint(Palette.inkMuted)
        }
        .contextMenu {
            Button("Compléter", systemImage: "square.and.pencil") {
                router.openMoment(moment.persistentModelID)
            }
            Button("Supprimer", systemImage: "trash", role: .destructive) { delete(moment) }
        }
        .journalRow(top: 0, bottom: 0)
    }

    private func alertCard(_ hit: AlertHit) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tes repères")
                    .font(.caption)
                    .foregroundStyle(Palette.inkFaint)
                Text(hit.detail)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                if let signs = plan?.warningSigns, !signs.isEmpty {
                    Text(signs.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
                if let helps = plan?.whatHelps, !helps.isEmpty {
                    Text(helps.joined(separator: " · "))
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                }
                HStack(spacing: 16) {
                    Button("Mon plan") { router.openPlan() }
                        .frame(minHeight: 44)
                    if let phone = plan?.trustedPhone, let url = URL(string: "tel:\(phone.filter(\.isNumber))") {
                        Link("Appeler", destination: url)
                            .frame(minHeight: 44)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.ink)
            }
        }
    }

    private func delete(_ moment: Moment) {
        let snapshot = Moment(emotionKey: moment.emotionKey, intensity: moment.intensity, source: moment.source)
        snapshot.createdAt = moment.createdAt
        snapshot.thought = moment.thought
        snapshot.behavior = moment.behavior
        snapshot.behaviorTags = moment.behaviorTags
        snapshot.associations = moment.associations
        SpotlightIndex.remove(moment)
        context.delete(moment)
        try? context.save()
        ToastCenter.shared.show("Supprimé.") {
            context.insert(snapshot)
            try? context.save()
        }
    }
}

private struct GlanceGauge: View {
    var title: String
    var level: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            Text(DayLevel.word(level))
                .font(.caption.weight(level == 0 ? .regular : .semibold))
                .foregroundStyle(level == 0 ? Palette.inkFaint : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { step in
                    Circle()
                        .fill(step == level ? mark : Color.clear)
                        .overlay(Circle().strokeBorder(step == level ? mark : Palette.hairline, lineWidth: 1.5))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(DayLevel.word(level))")
    }

    private var mark: Color { level == 0 ? Palette.inkFaint : color }
}

private enum DayLevel {
    static let words = ["Aucun", "Léger", "Modéré", "Sévère"]

    static func word(_ level: Int) -> String {
        words[min(max(level, 0), 3)]
    }
}

private extension View {
    func journalRow(top: CGFloat, bottom: CGFloat, trailing: CGFloat = 20) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: trailing))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
