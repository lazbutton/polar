import SwiftData
import SwiftUI

struct LabResultsPage: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \LabResult.date, order: .reverse) private var labs: [LabResult]

    var body: some View {
        Form {
            if labs.isEmpty {
                Text("Aucune analyse.")
                    .foregroundStyle(Palette.inkMuted)
            }
            ForEach(labs) { lab in
                HStack {
                    VStack(alignment: .leading) {
                        Text(lab.name)
                        Text(lab.date.formatted(.dateTime.day().month(.wide).year().locale(French.locale)))
                            .font(.caption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    Text("\(formatted(lab.value)) \(lab.unit)")
                        .monospacedDigit()
                }
            }
            .onDelete { offsets in
                offsets.map { labs[$0] }.forEach(context.delete)
                try? context.save()
            }
            Button("Ajouter une analyse") { router.present(.newLabResult) }
        }
        .navigationTitle("Analyses")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

struct LabResultForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""
    @State private var unit = ""
    @State private var date = Date.now

    private var canFinish: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(value.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Valeur", text: $value)
                .keyboardType(.decimalPad)
            TextField("Unité", text: $unit)
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
        .navigationTitle("Nouvelle analyse")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { save() }
                    .disabled(!canFinish)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
        context.insert(LabResult(name: trimmed, value: number, unit: unit, date: date))
        try? context.save()
        dismiss()
    }
}

struct ResourcesPage: View {
    var body: some View {
        Form {
            Link("Fondation FondaMental", destination: URL(string: "https://www.fondation-fondamental.org")!)
            Link("Psycom", destination: URL(string: "https://www.psycom.org")!)
            Link("Argos 2001", destination: URL(string: "https://www.argos2001.fr")!)
            Link("Unafam", destination: URL(string: "https://www.unafam.org")!)
        }
        .navigationTitle("Ressources")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
    }
}

/// Un contact de la liste unique. Le modifier ici le modifie partout.
struct ContactPage: View {
    var contactID: UUID
    @Environment(\.modelContext) private var context
    @State private var plan: CarePlan?
    @State private var name = ""
    @State private var phone = ""
    @State private var role: ContactRole?
    @State private var ready = false

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Téléphone", text: $phone)
                .keyboardType(.phonePad)
            Picker("Rôle", selection: $role) {
                Text("Aucun").tag(ContactRole?.none)
                ForEach([ContactRole.trusted, .therapist, .doctor, .other], id: \.self) { item in
                    Text(item.label).tag(Optional(item))
                }
            }
        }
        .navigationTitle(name.isEmpty ? "Contact" : name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .task {
            plan = try? CarePlan.findOrCreate(in: context)
            guard let contact = plan?.contacts.first(where: { $0.id == contactID }) else { return }
            name = contact.name
            phone = contact.phone
            role = contact.role
            ready = true
        }
        .onChange(of: name) { _, _ in save() }
        .onChange(of: phone) { _, _ in save() }
        .onChange(of: role) { _, _ in save() }
    }

    private func save() {
        guard ready, let plan, let index = plan.contacts.firstIndex(where: { $0.id == contactID }) else { return }
        plan.contacts[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.contacts[index].phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.contacts[index].role = role
        try? context.save()
    }
}

struct ContactForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var plan: CarePlan?
    @State private var name = ""
    @State private var phone = ""
    @State private var role: ContactRole?

    private var canFinish: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Téléphone", text: $phone)
                .keyboardType(.phonePad)
            Picker("Rôle", selection: $role) {
                Text("Aucun").tag(ContactRole?.none)
                ForEach([ContactRole.trusted, .therapist, .doctor, .other], id: \.self) { item in
                    Text(item.label).tag(Optional(item))
                }
            }
        }
        .navigationTitle("Nouveau contact")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") { save() }
                    .disabled(!canFinish)
            }
        }
        .task { plan = try? CarePlan.findOrCreate(in: context) }
    }

    private func save() {
        guard let plan, canFinish else { return }
        plan.contacts.append(Contact(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role
        ))
        try? context.save()
        dismiss()
    }
}
