import CoreLocation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showImporter = false
    @State private var location = LocationReader()

    var body: some View {
        @Bindable var preferences = preferences
        Form {
                Section("Traitements") {
                    ForEach(medications) { medication in
                        NavigationLink(value: AppRoute.medication(medication.persistentModelID)) {
                            VStack(alignment: .leading) {
                                Text(medication.name)
                                    .foregroundStyle(medication.isActive ? Palette.ink : Palette.inkMuted)
                                Text("\(medication.dose) · \(medication.slot)\(medication.isActive ? "" : " · archivé")")
                                    .font(.caption)
                                    .foregroundStyle(Palette.inkMuted)
                            }
                        }
                    }
                    NavigationLink("Ajouter", value: AppRoute.medication(nil))
                }
                Section("Points suivis") {
                    Toggle("Humeur basse", isOn: $preferences.trackDepressed)
                    Toggle("Humeur haute", isOn: $preferences.trackElevated)
                    Toggle("Irritabilité", isOn: $preferences.trackIrritability)
                    Toggle("Anxiété", isOn: $preferences.trackAnxiety)
                    Toggle("Symptômes psychotiques", isOn: $preferences.trackPsychotic)
                    Toggle("Poids", isOn: $preferences.trackWeight)
                    Toggle("Séance", isOn: $preferences.trackTherapy)
                    customPoints
                }
                Section("Rappels") {
                    Toggle("Bilan du soir", isOn: $preferences.eveningReminderEnabled)
                    Stepper("Heure \(preferences.eveningHour) h \(preferences.eveningMinute)", value: $preferences.eveningHour, in: 0...23)
                }
                Section("Journée") {
                    Stepper("Bascule à \(preferences.startHour) h", value: $preferences.startHour, in: 0...10)
                }
                Section {
                    NavigationLink("Mon plan", value: AppRoute.plan)
                }
                Section("Confidentialité") {
                    Toggle("Face ID à l'ouverture", isOn: $preferences.faceIDEnabled)
                    Toggle("Flou dans le sélecteur d'apps", isOn: $preferences.blurInSwitcher)
                    Toggle("Synchro iCloud", isOn: $preferences.cloudKitEnabled)
                    Text("Relance Polar pour appliquer la synchro. Elle reste coupée si iCloud n'est pas autorisé.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                Section("Santé") {
                    Toggle("Écrire les émotions dans Santé", isOn: $preferences.healthWriteEnabled)
                    Button("Autoriser Santé") {
                        Task { try? await HealthService.shared.requestAccess() }
                    }
                }
                Section("Compagnon") {
                    Toggle("Phrases", isOn: $preferences.companionPhrases)
                    Toggle("IA sur l'appareil", isOn: $preferences.aiEnabled)
                }
                Section("Apparence") {
                    Picker("Mode", selection: $preferences.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                    }
                    if preferences.appearance == .automaticNight {
                        Stepper("Nuit à partir de \(preferences.nightStartHour) h", value: $preferences.nightStartHour, in: 18...23)
                    }
                }
                Section("Puces de comportement") {
                    ForEach(preferences.behaviorTags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { preferences.behaviorTags.remove(atOffsets: $0) }
                    Button("Revenir aux puces d'origine") {
                        preferences.behaviorTags = Preferences.defaultBehaviorTags
                    }
                }
                Section("Données") {
                    Button("Importer une sauvegarde JSON") { showImporter = true }
                    Button("Lumière du jour, position approximative") {
                        location.onUpdate = { place in
                            preferences.latitude = place.coordinate.latitude
                            preferences.longitude = place.coordinate.longitude
                            preferences.save()
                        }
                        location.request()
                    }
                }
            }
            .navigationTitle("Réglages")
            .tint(Palette.ink)
            .onChange(of: preferences.eveningReminderEnabled) { _, _ in reschedule() }
            .onChange(of: preferences.eveningHour) { _, _ in reschedule() }
            .onDisappear { preferences.save() }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                guard let url = try? result.get(),
                      url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    try? Backup.replace(data: data, in: context)
                }
            }
    }

    private var customPoints: some View {
        ForEach(preferences.customPointNames, id: \.self) { name in
            Text(name)
        }
        .onDelete { preferences.customPointNames.remove(atOffsets: $0) }
    }

    private func reschedule() {
        preferences.save()
        Task {
            if preferences.eveningReminderEnabled || medications.contains(where: { $0.reminder != nil }) {
                _ = await Reminders.requestAccess()
            }
            await Reminders.reschedule(medications: medications)
        }
    }
}

struct MedicationForm: View {
    var medicationID: PersistentIdentifier?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var medications: [Medication]
    @State private var name = ""
    @State private var dose = ""
    @State private var slot = "soir"
    @State private var reminderOn = false
    @State private var reminder = Date.now

    private var medication: Medication? {
        guard let medicationID else { return nil }
        return medications.first { $0.persistentModelID == medicationID }
    }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Dose", text: $dose)
            Picker("Moment", selection: $slot) {
                ForEach(MedicationSlot.all, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Rappel", isOn: $reminderOn)
            if reminderOn {
                DatePicker("Heure", selection: $reminder, displayedComponents: .hourAndMinute)
            }
            if medicationID != nil {
                Button(medication?.isActive == true ? "Archiver" : "Réactiver") {
                    medication?.isActive = !(medication?.isActive ?? true)
                    try? context.save()
                    Task { await Reminders.reschedule(medications: medications) }
                    dismiss()
                }
            }
            Button("Enregistrer") { save() }
        }
        .navigationTitle(medicationID == nil ? "Traitement" : name)
        .task(id: medicationID) {
            guard let medication else { return }
            name = medication.name
            dose = medication.dose
            slot = medication.slot
            if let time = medication.reminder {
                reminderOn = true
                reminder = time
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let target: Medication
        if let medication {
            target = medication
            target.name = trimmed
            target.dose = dose
            target.slot = slot
        } else {
            target = Medication(name: trimmed, dose: dose, slot: slot)
            context.insert(target)
        }
        target.reminder = reminderOn ? reminder : nil
        try? context.save()
        Task { await Reminders.reschedule(medications: medications) }
        dismiss()
    }
}

final class LocationReader: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var onUpdate: ((CLLocation) -> Void)?

    func request() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let place = locations.last { onUpdate?(place) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
