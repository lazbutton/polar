import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \DayLog.day, order: .reverse) private var logs: [DayLog]
    @Query private var plans: [CarePlan]
    @Query(sort: \SurveyResponse.date, order: .reverse) private var surveys: [SurveyResponse]
    @Query(sort: \TherapySession.date) private var sessions: [TherapySession]

    private var today: Date { Date.now.logicalDay(startHour: preferences.startHour) }
    private var todaysMoments: [Moment] {
        Journal.moments(moments, on: .now, startHour: preferences.startHour)
    }
    private var log: DayLog? {
        logs.first { Calendar.current.isDate($0.day, inSameDayAs: today) }
    }
    private var plan: CarePlan? { plans.first }
    private var hits: [AlertHit] {
        guard !preferences.isPaused() else { return [] }
        return AlertEngine.hits(
            rules: preferences.alertRules,
            logs: logs,
            plan: plan,
            surveys: surveys,
            startHour: preferences.startHour
        )
    }
    private var eveningPending: Bool { preferences.isPastEveningReminder() && log == nil }
    private var weeklyPending: Bool {
        WeeklySchedule.showsCard(
            enabled: preferences.weeklyEnabled,
            weekday: preferences.weeklyWeekday,
            everyTwoWeeks: preferences.weeklyEveryTwoWeeks,
            paused: preferences.isPaused(),
            now: .now,
            surveyDates: surveys.map(\.date)
        )
    }

    private var sessionEve: Bool {
        guard let next = SessionFacts.nextSession(in: sessions) else { return false }
        let today = Date.now.logicalDay(startHour: preferences.startHour)
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else { return false }
        return Calendar.current.isDate(next.date.logicalDay(startHour: preferences.startHour), inSameDayAs: tomorrow)
    }

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
                Text(French.weekday(.now))
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(French.dayNumber(.now))
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(French.monthName(.now))
                        .font(.title3.weight(.medium))
                }
                .foregroundStyle(Palette.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(French.dayTitle(.now))
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
            if weeklyPending {
                weeklyCard
                    .journalRow(top: 6, bottom: 4)
            }
            if sessionEve {
                sessionCard
                    .journalRow(top: 6, bottom: 4)
            }
            Text("Moments")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .journalRow(top: 12, bottom: 4)
            if todaysMoments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rien de noté aujourd'hui.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                    Text("Touche Noter, en bas, pour en noter un.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkFaint)
                }
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
        .contentMargins(.bottom, 88, for: .scrollContent)
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
                    if let hours = log?.resolvedSleepHours {
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
                    if log.resolvedSleepHours == nil {
                        Text("Sommeil non noté")
                            .font(.caption)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        GlanceGauge(title: "Humeur basse", level: log.depressed, color: Palette.depressed)
                        GlanceGauge(title: "Humeur haute", level: log.elevated, color: Palette.elevated)
                        GlanceGauge(title: "Irritabilité", level: log.irritability, color: Palette.irritability)
                        GlanceGauge(title: "Anxiété", level: log.anxiety, color: Palette.anxiety)
                    }
                    if let energy = log.energy {
                        Text("Énergie \(EnergyRow.word(energy))")
                            .font(.caption)
                            .foregroundStyle(Palette.inkMuted)
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
        if let hours = log.resolvedSleepHours {
            parts.append("Sommeil \(French.sleep(hours))")
        }
        parts.append("Humeur basse \(French.level(log.depressed))")
        parts.append("Humeur haute \(French.level(log.elevated))")
        parts.append("Irritabilité \(French.level(log.irritability))")
        parts.append("Anxiété \(French.level(log.anxiety))")
        return parts.joined(separator: ", ")
    }

    private var sessionCard: some View {
        Button { router.push(.forPsy) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pour ma psy")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Séance demain")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var weeklyCard: some View {
        Button { router.openWeeklyCheck() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Point de la semaine")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text("2 min")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .journalRow(top: 4, bottom: 4)
    }

    private func alertCard(_ hit: AlertHit) -> some View {
        let actions = planActions(for: hit)
        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tes repères")
                    .font(.caption)
                    .foregroundStyle(Palette.inkFaint)
                Text(hit.detail)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                if !actions.isEmpty {
                    ForEach(actions) { action in
                        Text(action.text)
                            .font(.body)
                            .foregroundStyle(Palette.ink)
                    }
                }
                HStack(spacing: 16) {
                    Button("Voir mon plan") {
                        if let pole = hit.pole {
                            router.push(.pole(pole, stage: hit.stage))
                        } else {
                            router.tab = .plan
                            router.plan = []
                        }
                    }
                        .frame(minHeight: 44)
                    if let phone = plan?.contacts.first?.digits, !phone.isEmpty, let url = URL(string: "tel:\(phone)") {
                        Link("Appeler", destination: url)
                            .frame(minHeight: 44)
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.ink)
            }
        }
    }

    private func planActions(for hit: AlertHit) -> [PlanAction] {
        guard let plan, let pole = hit.pole, let stage = PlanStage(rawValue: hit.stage) else { return [] }
        return plan.actions(pole: pole, stage: stage)
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
            Text(French.level(level))
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
        .accessibilityLabel("\(title), \(French.level(level))")
    }

    private var mark: Color { level == 0 ? Palette.inkFaint : color }
}

private extension View {
    func journalRow(top: CGFloat, bottom: CGFloat, trailing: CGFloat = 20) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: trailing))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
