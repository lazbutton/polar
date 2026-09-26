import SwiftData
import SwiftUI

struct DayLogSheet: View {
    var date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]
    @Query(sort: \DayLog.day, order: .reverse) private var logs: [DayLog]
    @Query private var plans: [CarePlan]

    @State private var depressed = 0
    @State private var elevated = 0
    @State private var irritability = 0
    @State private var anxiety = 0
    @State private var energy: Int?
    @State private var sleepHours = 7.0
    @State private var sleepEdited = false
    @State private var sleepFromHealth = false
    @State private var bedtime: Date?
    @State private var wakeTime: Date?
    @State private var firstContact: Date?
    @State private var activityStart: Date?
    @State private var dinner: Date?
    @State private var signsSeen: Set<UUID> = []
    @State private var factors: [String: Int] = [:]
    @State private var psychotic = false
    @State private var weight = ""
    @State private var therapy = false
    @State private var note = ""
    @State private var marks: Set<String> = []
    @State private var doseDrafts: [String: String] = [:]
    @State private var loaded = false
    @State private var ready = false

    private var logicalDay: Date { date.logicalDay(startHour: preferences.startHour) }
    private var activeMeds: [Medication] { medications.filter(\.isActive) }
    private var dayMoments: [Moment] { Journal.moments(moments, on: date, startHour: preferences.startHour) }
    private var plan: CarePlan? { plans.first }
    private var yesterday: DayLog? {
        guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: logicalDay) else { return nil }
        return logs.first { Calendar.current.isDate($0.day, inSameDayAs: previous) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Le niveau le plus fort de la journée")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                if preferences.trackDepressed {
                    ScaleRow(title: "Humeur basse", tint: Palette.depressed, yesterday: yesterday?.depressed, value: $depressed)
                }
                if preferences.trackElevated {
                    ScaleRow(title: "Humeur haute", tint: Palette.elevated, yesterday: yesterday?.elevated, value: $elevated)
                }
                if preferences.trackIrritability {
                    ScaleRow(title: "Irritabilité", tint: Palette.irritability, yesterday: yesterday?.irritability, value: $irritability)
                }
                if preferences.trackAnxiety {
                    ScaleRow(title: "Anxiété", tint: Palette.anxiety, yesterday: yesterday?.anxiety, value: $anxiety)
                }
                if preferences.trackEnergy {
                    energyBlock
                }
                sleepBlock
                signsBlock
                if preferences.trackRhythm {
                    rhythmBlock
                }
                if preferences.trackFactors {
                    factorsBlock
                }
                if preferences.trackPsychotic {
                    Toggle("Symptômes psychotiques", isOn: $psychotic).tint(Palette.ink)
                }
                if preferences.trackWeight {
                    TextField("Poids, kg", text: $weight)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if preferences.trackTherapy {
                    Toggle("Séance avec ta psy", isOn: $therapy).tint(Palette.ink)
                }
                ForEach(preferences.customPointNames, id: \.self) { name in
                    Toggle(name, isOn: Binding(
                        get: { marks.contains(name) },
                        set: { on in if on { marks.insert(name) } else { marks.remove(name) } }
                    ))
                    .tint(Palette.ink)
                }
                meds
                TextField("Note du jour", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let hours = daylightHours {
                    Text("Lumière du jour \(Daylight.label(for: hours))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
                if !dayMoments.isEmpty {
                    Text("Aujourd'hui : \(dayMoments.count) moment\(dayMoments.count > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                    ForEach(dayMoments) { moment in
                        Text("\(French.time(moment.createdAt))  \(moment.emotionLabel)")
                            .font(.subheadline)
                    }
                }
                if yesterday != nil {
                    Text("◌ = ton niveau d'hier")
                        .font(.caption)
                        .foregroundStyle(Palette.inkFaint)
                }
                Button("Terminé") {
                    persist()
                    dismiss()
                }
                    .font(.headline)
                    .foregroundStyle(Palette.background)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Palette.ink, in: Capsule())
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("Bilan du jour")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .onChange(of: depressed) { _, _ in if ready { persist() } }
        .onChange(of: elevated) { _, _ in if ready { persist() } }
        .onChange(of: irritability) { _, _ in if ready { persist() } }
        .onChange(of: anxiety) { _, _ in if ready { persist() } }
        .onChange(of: energy) { _, _ in if ready { persist() } }
        .onChange(of: sleepHours) { _, _ in
            guard ready else { return }
            sleepEdited = true
            sleepFromHealth = false
            persist()
        }
        .onChange(of: bedtime) { _, _ in if ready { syncSleepFromTiming(); persist() } }
        .onChange(of: wakeTime) { _, _ in if ready { syncSleepFromTiming(); persist() } }
        .onChange(of: firstContact) { _, _ in if ready { persist() } }
        .onChange(of: activityStart) { _, _ in if ready { persist() } }
        .onChange(of: dinner) { _, _ in if ready { persist() } }
        .onChange(of: signsSeen) { _, _ in if ready { persist() } }
        .onChange(of: factors) { _, _ in if ready { persist() } }
        .onChange(of: psychotic) { _, _ in if ready { persist() } }
        .onChange(of: weight) { _, _ in if ready { persist() } }
        .onChange(of: therapy) { _, _ in if ready { persist() } }
        .onChange(of: note) { _, _ in if ready { persist() } }
        .onChange(of: marks) { _, _ in if ready { persist() } }
    }

    private var energyBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            EnergyRow(title: "Énergie", yesterday: yesterday?.energy, value: $energy)
            Text("Ton énergie et ton activité aujourd'hui, par rapport à d'habitude.")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private var sleepBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sommeil")
                Spacer()
                Text(French.sleep(sleepHours))
                    .font(.title.monospacedDigit())
                    .fontDesign(.rounded)
                if sleepFromHealth {
                    Text("Santé")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            HStack(spacing: 16) {
                timeField("Coucher", selection: bedtimeBinding)
                Image(systemName: "arrow.right").foregroundStyle(Palette.inkFaint)
                timeField("Lever", selection: wakeBinding)
            }
            if bedtime == nil || wakeTime == nil {
                hoursPicker
            }
        }
    }

    private func timeField(_ title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Palette.inkMuted)
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: { bedtime ?? defaultBedtime },
            set: { bedtime = $0 }
        )
    }

    private var wakeBinding: Binding<Date> {
        Binding(
            get: { wakeTime ?? defaultWake },
            set: { wakeTime = $0 }
        )
    }

    private var defaultBedtime: Date {
        Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Calendar.current.date(byAdding: .day, value: -1, to: logicalDay) ?? logicalDay) ?? logicalDay
    }

    private var defaultWake: Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: logicalDay) ?? logicalDay
    }

    private var hoursPicker: some View {
        HStack {
            Picker("Heures", selection: Binding(
                get: { Int(sleepHours) },
                set: { sleepHours = Double($0) + sleepHours.truncatingRemainder(dividingBy: 1) }
            )) {
                ForEach(0..<15, id: \.self) { Text("\($0) h").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            Picker("Minutes", selection: Binding(
                get: { Int((sleepHours * 60).rounded()) % 60 },
                set: { minutes in sleepHours = Double(Int(sleepHours)) + Double(minutes) / 60 }
            )) {
                ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
    }

    @ViewBuilder
    private var signsBlock: some View {
        let signs = plan?.signs ?? []
        if !signs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Signes remarqués aujourd'hui")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                FlowLayout {
                    ForEach(signs) { sign in
                        EmotionChip(title: sign.text, selected: signsSeen.contains(sign.id)) {
                            if signsSeen.contains(sign.id) { signsSeen.remove(sign.id) }
                            else { signsSeen.insert(sign.id) }
                        }
                    }
                }
            }
        }
    }

    private var rhythmBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rythme du jour")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            anchorRow("Premier contact", value: $firstContact)
            anchorRow("Début d'activité", value: $activityStart)
            anchorRow("Dîner", value: $dinner)
        }
    }

    private func anchorRow(_ title: String, value: Binding<Date?>) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.ink)
            Spacer()
            if let date = value.wrappedValue {
                Text(French.time(date)).monospacedDigit().foregroundStyle(Palette.ink)
                Button {
                    value.wrappedValue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
            } else {
                Button("Maintenant") { value.wrappedValue = .now }
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(minHeight: 44)
    }

    private var factorsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Facteurs")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            FlowLayout {
                ForEach(FactorCatalog.all) { factor in
                    let count = factors[factor.id] ?? 0
                    Button {
                        factors[factor.id] = count + 1
                    } label: {
                        Text(count > 0 ? "\(factor.label) \(count)" : factor.label)
                            .font(.subheadline)
                            .foregroundStyle(count > 0 ? Palette.background : Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(count > 0 ? Palette.ink : Palette.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(LongPressGesture().onEnded { _ in factors[factor.id] = 0 })
                }
            }
            Text("Touche pour +1, maintiens pour remettre à 0.")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private var meds: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !activeMeds.isEmpty {
                HStack {
                    Text("Traitements").foregroundStyle(Palette.ink)
                    Spacer()
                    Button("Tout pris") { markAllTaken() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                }
            }
            ForEach(activeMeds) { medication in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: intakeBinding(medication)) {
                        VStack(alignment: .leading) {
                            Text(medication.name)
                            Text("\(medication.dose) · \(medication.slot)")
                                .font(.caption)
                                .foregroundStyle(Palette.inkMuted)
                        }
                    }
                    .tint(Palette.ink)
                    TextField("Changement de dose", text: doseBinding(medication))
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
    }

    private var daylightHours: TimeInterval? {
        guard let latitude = preferences.latitude, let longitude = preferences.longitude else { return nil }
        return Daylight.duration(on: logicalDay, latitude: latitude, longitude: longitude)
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true
        if let existing = try? DayLog.existing(for: date, startHour: preferences.startHour, in: context) {
            depressed = existing.depressed
            elevated = existing.elevated
            irritability = existing.irritability
            anxiety = existing.anxiety
            energy = existing.energy
            if let hours = existing.sleepHours { sleepHours = hours }
            sleepFromHealth = existing.sleepFromHealth
            bedtime = existing.bedtime
            wakeTime = existing.wakeTime
            firstContact = existing.firstContact
            activityStart = existing.activityStart
            dinner = existing.dinner
            signsSeen = Set(existing.signsSeen)
            factors = Dictionary(uniqueKeysWithValues: existing.factors.map { ($0.key, $0.count) })
            psychotic = existing.psychoticSymptoms ?? false
            if let weightKg = existing.weightKg { weight = String(weightKg) }
            therapy = existing.therapySession
            note = existing.note ?? ""
            marks = Set(existing.customMarks)
        } else {
            if let timing = await HealthService.shared.sleepTiming(for: logicalDay) {
                bedtime = timing.bedtime
                wakeTime = timing.wake
                sleepHours = timing.wake.timeIntervalSince(timing.bedtime) / 3600
                sleepFromHealth = true
                sleepEdited = false
            } else if let hours = await HealthService.shared.sleepHours(for: logicalDay) {
                sleepHours = hours
                sleepFromHealth = true
                sleepEdited = false
            }
        }
        try? await Task.sleep(for: .milliseconds(350))
        ready = true
    }

    private func syncSleepFromTiming() {
        guard let bedtime, let wakeTime, wakeTime > bedtime else { return }
        sleepHours = wakeTime.timeIntervalSince(bedtime) / 3600
        sleepEdited = true
    }

    private func persist() {
        guard loaded else { return }
        do {
            let log = try DayLog.findOrCreate(for: date, startHour: preferences.startHour, in: context)
            log.depressed = depressed
            log.elevated = elevated
            log.irritability = irritability
            log.anxiety = anxiety
            log.energy = preferences.trackEnergy ? energy : nil
            log.sleepHours = sleepHours
            log.sleepFromHealth = sleepFromHealth && !sleepEdited
            log.bedtime = bedtime
            log.wakeTime = wakeTime
            log.firstContact = firstContact
            log.activityStart = activityStart
            log.dinner = dinner
            log.signsSeen = Array(signsSeen)
            log.factors = factors.filter { $0.value > 0 }.map { FactorCount(key: $0.key, count: $0.value) }
            log.psychoticSymptoms = preferences.trackPsychotic ? psychotic : nil
            log.weightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
            log.therapySession = therapy
            log.note = note.isEmpty ? nil : note
            log.customMarks = Array(marks)
            try context.save()
        } catch {}
    }

    private func markAllTaken() {
        guard let log = try? DayLog.findOrCreate(for: date, startHour: preferences.startHour, in: context) else { return }
        for medication in activeMeds {
            if let intake = log.intakes?.first(where: { $0.medication?.persistentModelID == medication.persistentModelID }) {
                intake.taken = true
                intake.at = .now
            } else {
                context.insert(MedIntake(medication: medication, dayLog: log, taken: true))
            }
        }
        try? context.save()
    }

    private func intakeBinding(_ medication: Medication) -> Binding<Bool> {
        Binding(
            get: {
                guard let log = try? DayLog.existing(for: date, startHour: preferences.startHour, in: context) else { return false }
                return log.intakes?.first { $0.medication?.persistentModelID == medication.persistentModelID }?.taken ?? false
            },
            set: { taken in
                guard let log = try? DayLog.findOrCreate(for: date, startHour: preferences.startHour, in: context) else { return }
                if let intake = log.intakes?.first(where: { $0.medication?.persistentModelID == medication.persistentModelID }) {
                    intake.taken = taken
                    intake.at = .now
                } else {
                    context.insert(MedIntake(medication: medication, dayLog: log, taken: taken))
                }
                try? context.save()
            }
        )
    }

    private func doseBinding(_ medication: Medication) -> Binding<String> {
        Binding(
            get: { doseDrafts[medication.name] ?? "" },
            set: { value in
                doseDrafts[medication.name] = value
                guard let log = try? DayLog.findOrCreate(for: date, startHour: preferences.startHour, in: context) else { return }
                let intake = log.intakes?.first { $0.medication?.persistentModelID == medication.persistentModelID }
                if let intake {
                    intake.doseChange = value.isEmpty ? nil : value
                } else if !value.isEmpty {
                    let created = MedIntake(medication: medication, dayLog: log, taken: false)
                    created.doseChange = value
                    context.insert(created)
                }
                try? context.save()
            }
        )
    }
}
