import SwiftData
import SwiftUI

struct DayPage: View {
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query private var plans: [CarePlan]
    @State private var day: Date

    init(day: Date) {
        _day = State(initialValue: day)
    }

    private var calendar: Calendar { .current }
    private var log: DayLog? { logs.first { calendar.isDate($0.day, inSameDayAs: day) } }
    private var dayMoments: [Moment] { Journal.moments(moments, on: day, startHour: preferences.startHour) }
    private var isEmpty: Bool {
        log == nil && dayMoments.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(French.dayTitle(day))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if isEmpty {
                    Text("Rien de noté ce jour-là.")
                        .foregroundStyle(Palette.inkMuted)
                    Button("Faire le bilan de ce jour") { router.present(.dayLog(day)) }
                        .buttonStyle(PolarPrimaryButton())
                } else {
                    bilan
                    sleep
                    momentList
                    if let note = log?.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(note)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Jour précédent")
                    Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Jour suivant")
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                shift(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private var bilan: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bilan")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if log != nil {
                    Button("Modifier") { router.present(.dayLog(day)) }
                        .foregroundStyle(Palette.ink)
                }
            }
            if let log {
                HStack(alignment: .top) {
                    reading("Basse", French.level(log.depressed))
                    reading("Haute", French.level(log.elevated))
                    reading("Irrit.", French.level(log.irritability))
                    reading("Anx.", French.level(log.anxiety))
                    reading("Én.", log.energy.map { EnergyRow.word($0) } ?? "—")
                }
                if let signs = signLine(log), !signs.isEmpty {
                    Text("Signes : \(signs)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
                if let intakes = log.intakes, !intakes.isEmpty {
                    let taken = intakes.allSatisfy(\.taken)
                    Text(taken ? "Traitement du soir : pris" : "Traitement : pas pris")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
            } else {
                Button("Faire le bilan de ce jour") { router.present(.dayLog(day)) }
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    private var sleep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sommeil et activité")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let log, let night = log.resolvedSleepNight(), let hours = log.resolvedSleepHours {
                Text("\(French.time(night.bedtime)) → \(French.time(night.wake)) · \(French.sleep(hours))")
                    .foregroundStyle(Palette.ink)
            } else if let hours = log?.resolvedSleepHours {
                Text(French.sleep(hours))
                    .foregroundStyle(Palette.ink)
            } else {
                Text("Sommeil non noté")
                    .foregroundStyle(Palette.inkMuted)
            }
            HStack(spacing: 12) {
                if let steps = log?.steps {
                    Text("\(steps) pas")
                }
                if let light = log?.daylightMinutes {
                    Text("\(Int(light.rounded())) min de lumière")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.inkMuted)
        }
    }

    private var momentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moments")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if dayMoments.isEmpty {
                Text("Aucun moment.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            }
            ForEach(dayMoments) { moment in
                Button {
                    router.present(.moment(moment.persistentModelID))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(French.time(moment.createdAt))
                                    .foregroundStyle(Palette.inkMuted)
                                Text(moment.emotionKey == nil ? "À compléter" : moment.emotionLabel)
                                if let intensity = moment.intensity {
                                    Text("· \(intensity)").foregroundStyle(Palette.inkMuted)
                                }
                            }
                            if let thought = moment.thought, !thought.isEmpty {
                                Text(thought).font(.caption).foregroundStyle(Palette.inkMuted).lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkFaint)
                    }
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reading(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Palette.inkMuted)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signLine(_ log: DayLog) -> String? {
        let signs = plans.first?.signs ?? []
        let names = log.signsSeen.compactMap { id in signs.first { $0.id == id }?.text }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    private func shift(_ value: Int) {
        day = calendar.date(byAdding: .day, value: value, to: day) ?? day
    }
}
