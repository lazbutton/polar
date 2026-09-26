import SwiftData
import SwiftUI

struct MedicationPage: View {
    var medicationID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Query private var medications: [Medication]
    @State private var name = ""
    @State private var dose = ""
    @State private var slot = "soir"
    @State private var reminderOn = false
    @State private var reminder = Date.now
    @State private var ready = false

    private var medication: Medication? {
        medications.first { $0.persistentModelID == medicationID }
    }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Dose", text: $dose)
            Picker("Moment de prise", selection: $slot) {
                ForEach(MedicationSlot.all, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Rappel", isOn: $reminderOn)
            if reminderOn {
                DatePicker("Heure", selection: $reminder, displayedComponents: .hourAndMinute)
            }
            Section {
                Button(medication?.isActive == true ? "Archiver" : "Réactiver") {
                    guard let medication else { return }
                    medication.isActive.toggle()
                    try? context.save()
                    Task { await Reminders.reschedule(medications: medications) }
                }
                .foregroundStyle(Palette.ink)
            }
        }
        .navigationTitle(name.isEmpty ? "Traitement" : name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .task {
            guard let medication else { return }
            name = medication.name
            dose = medication.dose
            slot = medication.slot
            if let time = medication.reminder {
                reminderOn = true
                reminder = time
            }
            ready = true
        }
        .onChange(of: name) { _, _ in save() }
        .onChange(of: dose) { _, _ in save() }
        .onChange(of: slot) { _, _ in save() }
        .onChange(of: reminderOn) { _, _ in save() }
        .onChange(of: reminder) { _, _ in save() }
    }

    private func save() {
        guard ready, let medication else { return }
        medication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.dose = dose
        medication.slot = slot
        medication.reminder = reminderOn ? reminder : nil
        try? context.save()
        Task { await Reminders.reschedule(medications: medications) }
    }
}

struct MedicationForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var medications: [Medication]
    @State private var name = ""
    @State private var dose = ""
    @State private var slot = "soir"
    @State private var reminderOn = false
    @State private var reminder = Date.now

    private var canFinish: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Dose", text: $dose)
            Picker("Moment de prise", selection: $slot) {
                ForEach(MedicationSlot.all, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Rappel", isOn: $reminderOn)
            if reminderOn {
                DatePicker("Heure", selection: $reminder, displayedComponents: .hourAndMinute)
            }
        }
        .navigationTitle("Nouveau traitement")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { save() }
                    .disabled(!canFinish)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let medication = Medication(name: trimmed, dose: dose, slot: slot)
        medication.reminder = reminderOn ? reminder : nil
        context.insert(medication)
        try? context.save()
        Task { await Reminders.reschedule(medications: medications) }
        dismiss()
    }
}
