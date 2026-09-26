import SwiftData
import SwiftUI

struct DayLogSheet: View {
    var date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \Moment.createdAt, order: .reverse) private var moments: [Moment]

    @State private var depressed = 0
    @State private var elevated = 0
    @State private var irritability = 0
    @State private var anxiety = 0
    @State private var sleepHours = 7.0
    @State private var sleepEdited = false
    @State private var sleepFromHealth = false
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Le niveau le plus fort de la journée")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                if preferences.trackDepressed {
                    ScaleRow(title: "Humeur basse", tint: Palette.depressed, value: $depressed)
                }
                if preferences.trackElevated {
                    ScaleRow(title: "Humeur haute", tint: Palette.elevated, value: $elevated)
                }
                if preferences.trackIrritability {
                    ScaleRow(title: "Irritabilité", tint: Palette.irritability, value: $irritability)
                }
                if preferences.trackAnxiety {
                    ScaleRow(title: "Anxiété", tint: Palette.anxiety, value: $anxiety)
                }
                sleepRow
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
        .onChange(of: sleepHours) { _, _ in
            guard ready else { return }
            sleepEdited = true
            sleepFromHealth = false
            persist()
        }
        .onChange(of: psychotic) { _, _ in if ready { persist() } }
        .onChange(of: weight) { _, _ in if ready { persist() } }
        .onChange(of: therapy) { _, _ in if ready { persist() } }
        .onChange(of: note) { _, _ in if ready { persist() } }
        .onChange(of: marks) { _, _ in if ready { persist() } }
    }

    private var sleepRow: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    set: { minutes in
                        sleepHours = Double(Int(sleepHours)) + Double(minutes) / 60
                    }
                )) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
        }
    }

    private var meds: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            if let hours = existing.sleepHours { sleepHours = hours }
            sleepFromHealth = existing.sleepFromHealth
            psychotic = existing.psychoticSymptoms ?? false
            if let weightKg = existing.weightKg { weight = String(weightKg) }
            therapy = existing.therapySession
            note = existing.note ?? ""
            marks = Set(existing.customMarks)
        } else if let hours = await HealthService.shared.sleepHours(for: logicalDay) {
            sleepHours = hours
            sleepFromHealth = true
            sleepEdited = false
        }
        try? await Task.sleep(for: .milliseconds(350))
        ready = true
    }

    private func persist() {
        guard loaded else { return }
        do {
            let log = try DayLog.findOrCreate(for: date, startHour: preferences.startHour, in: context)
            log.depressed = depressed
            log.elevated = elevated
            log.irritability = irritability
            log.anxiety = anxiety
            log.sleepHours = sleepHours
            log.sleepFromHealth = sleepFromHealth && !sleepEdited
            log.psychoticSymptoms = preferences.trackPsychotic ? psychotic : nil
            log.weightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
            log.therapySession = therapy
            log.note = note.isEmpty ? nil : note
            log.customMarks = Array(marks)
            try context.save()
        } catch {}
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
