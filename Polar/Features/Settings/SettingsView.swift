import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showImporter = false
    @State private var pendingImport: Data?
    @State private var confirmImport = false
    @State private var confirmErase = false
    @State private var exportItem: ShareFile?
    @State private var newQuestion = ""

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                DatePicker("Rappel du soir", selection: eveningBinding, displayedComponents: .hourAndMinute)
                    .onChange(of: preferences.eveningHour) { _, _ in reschedule(request: true) }
                    .onChange(of: preferences.eveningMinute) { _, _ in reschedule(request: true) }
                Stepper(value: $preferences.startHour, in: 0...10) {
                    Text("La journée commence à \(preferences.startHour):00")
                }
                .onChange(of: preferences.startHour) { _, _ in preferences.save() }
                Toggle("Rythme du jour", isOn: $preferences.trackRhythm)
                Toggle("Facteurs", isOn: $preferences.trackFactors)
                Toggle("Symptômes psychotiques", isOn: $preferences.trackPsychotic)
                Toggle("Poids", isOn: $preferences.trackWeight)
                HStack {
                    TextField("Ajouter une question", text: $newQuestion)
                    Button("OK") { addQuestion() }
                        .disabled(newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(preferences.customPointNames, id: \.self) { name in
                    Text(name)
                }
                .onDelete { preferences.customPointNames.remove(atOffsets: $0); preferences.save() }
            } header: {
                Text("Bilan du jour").accessibilityAddTraits(.isHeader)
            } footer: {
                Text("Questions en plus")
            }
            .headerProminence(.increased)

            Section {
                Toggle("Activé", isOn: $preferences.weeklyEnabled)
                Picker("Jour", selection: $preferences.weeklyWeekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Preferences.weekdayNames[day] ?? "").tag(day)
                    }
                }
                Toggle("Toutes les deux semaines", isOn: $preferences.weeklyEveryTwoWeeks)
                Toggle("Anxiété (GAD-7)", isOn: $preferences.includeGAD7)
            } header: {
                Text("Point de la semaine").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                Toggle("Face ID", isOn: $preferences.faceIDEnabled)
                Picker("Délai avant Face ID", selection: $preferences.graceDelay) {
                    Text("Immédiat").tag(0.0)
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                    Text("15 min").tag(900.0)
                }
                Toggle("Flou dans le sélecteur d'apps", isOn: $preferences.blurInSwitcher)
                Toggle("Notifications discrètes", isOn: $preferences.neutralNotifications)
            } header: {
                Text("Confidentialité").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                Button("Accès à Santé") {
                    Task { try? await HealthService.shared.requestAccess() }
                }
                Toggle("Écrire mes émotions dans Santé", isOn: $preferences.healthWriteEnabled)
                Toggle("IA sur l'iPhone", isOn: $preferences.aiEnabled)
                Toggle("iCloud", isOn: $preferences.cloudKitEnabled)
                Text("Relance Polar pour appliquer la synchro.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkMuted)
                Button("Sauvegarder") { exportJSON() }
                Button("Restaurer une sauvegarde") { showImporter = true }
                Button("Exporter en CSV") { exportCSV() }
                Button("Effacer toutes les données", role: .destructive) { confirmErase = true }
            } header: {
                Text("Santé et données").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                Picker("Apparence", selection: $preferences.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                if preferences.appearance == .automaticNight {
                    Stepper("Nuit à partir de \(preferences.nightStartHour) h", value: $preferences.nightStartHour, in: 18...23)
                }
                Toggle("Haptiques", isOn: $preferences.hapticsEnabled)
                Toggle("Mode discret", isOn: $preferences.discreetMode)
                Text("Le mode discret masque les courbes. Tes notes continuent.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkMuted)
                Toggle("Pause du suivi", isOn: Binding(
                    get: { preferences.isPaused() },
                    set: { on in
                        preferences.pauseUntil = on ? Calendar.current.date(byAdding: .day, value: 14, to: .now) : nil
                        preferences.save()
                        Task { await Reminders.reschedule(medications: medications) }
                    }
                ))
                if preferences.isPaused(), let until = preferences.pauseUntil {
                    DatePicker("Jusqu'au", selection: Binding(
                        get: { until },
                        set: { preferences.pauseUntil = $0; preferences.save() }
                    ), displayedComponents: .date)
                }
            } header: {
                Text("Affichage").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                Text("PHQ-9, GAD-7, ASRM, life chart, plan de sécurité de Stanley et Brown.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3")")
                    .foregroundStyle(Palette.inkMuted)
                Text("Polar ne remplace pas un avis médical.")
                    .font(.subheadline)
            } header: {
                Text("À propos").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .onDisappear { preferences.save() }
        .onChange(of: preferences.weeklyEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.weeklyWeekday) { _, _ in preferences.save() }
        .onChange(of: preferences.faceIDEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.discreetMode) { _, _ in preferences.save() }
        .onChange(of: preferences.hapticsEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.trackRhythm) { _, _ in preferences.save() }
        .onChange(of: preferences.trackFactors) { _, _ in preferences.save() }
        .onChange(of: preferences.trackPsychotic) { _, _ in preferences.save() }
        .onChange(of: preferences.trackWeight) { _, _ in preferences.save() }
        .onChange(of: preferences.aiEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.cloudKitEnabled) { _, _ in preferences.save() }
        .onChange(of: preferences.appearance) { _, _ in preferences.save() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            guard let url = try? result.get(), url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            pendingImport = try? Data(contentsOf: url)
            confirmImport = pendingImport != nil
        }
        .confirmationDialog("Restaurer cette sauvegarde ?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Restaurer", role: .destructive) {
                if let pendingImport {
                    try? Backup.replace(data: pendingImport, in: context)
                }
                pendingImport = nil
            }
            Button("Annuler", role: .cancel) { pendingImport = nil }
        }
        .confirmationDialog("Effacer toutes les données ?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { erase() }
            Button("Annuler", role: .cancel) {}
        }
        .sheet(item: $exportItem) { item in
            ShareLink(item: item.url) { Text("Partager") }
                .padding()
        }
    }

    private var eveningBinding: Binding<Date> {
        Binding(
            get: { preferences.eveningDate },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                preferences.eveningHour = parts.hour ?? preferences.eveningHour
                preferences.eveningMinute = parts.minute ?? preferences.eveningMinute
                preferences.eveningReminderEnabled = true
                preferences.save()
            }
        )
    }

    private func addQuestion() {
        let word = newQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        preferences.customPointNames.append(word)
        preferences.save()
        newQuestion = ""
    }

    private func reschedule(request: Bool) {
        preferences.eveningReminderEnabled = true
        preferences.save()
        Task {
            if request { _ = await Reminders.requestAccess() }
            await Reminders.reschedule(medications: medications)
        }
    }

    private func exportJSON() {
        guard let data = try? Backup.make(in: context) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Polar.json")
        try? data.write(to: url)
        exportItem = ShareFile(url: url)
    }

    private func exportCSV() {
        guard let text = try? CSVExport.make(in: context) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Polar.csv")
        try? Data(text.utf8).write(to: url)
        exportItem = ShareFile(url: url)
    }

    private func erase() {
        wipe(Moment.self)
        wipe(MedIntake.self)
        wipe(DayLog.self)
        wipe(Medication.self)
        wipe(CarePlan.self)
        wipe(SafetyPlan.self)
        wipe(SurveyResponse.self)
        wipe(LabResult.self)
        wipe(TherapySession.self)
        preferences.alertRules = []
        preferences.sessionQuestions = []
        preferences.save()
        try? context.save()
    }

    private func wipe<T: PersistentModel>(_ type: T.Type) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items { context.delete(item) }
    }
}
