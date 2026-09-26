import SwiftData
import SwiftUI

/// Plan de sécurité « Ça ne va pas », en six étapes (Stanley-Brown).
/// Toujours accessible, même en mode discret ou en pause du suivi.
struct SafetyPlanPage: View {
    @Environment(\.modelContext) private var context
    @Query private var cares: [CarePlan]
    @State private var plan: SafetyPlan?
    @State private var care: CarePlan?
    @State private var message = "Je ne vais pas très bien. Tu peux me rappeler ?"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let plan {
                    header(plan)
                    callButtons(plan)
                    StringListEditor(title: "Ce qui compte pour moi", systemImage: "heart", items: binding(for: \.reasons))
                    StringListEditor(title: "1 · Mes signes d'alerte", systemImage: "exclamationmark.triangle", items: binding(for: \.warningSigns))
                    StringListEditor(title: "2 · Me calmer seul", systemImage: "leaf", items: binding(for: \.copingAlone))
                    StringListEditor(title: "3 · Personnes et lieux qui apaisent", systemImage: "mappin.and.ellipse", items: binding(for: \.distractions))
                    SharedContactEditor(
                        title: "4 · Qui peut m'aider",
                        role: .trusted,
                        contacts: care?.contacts ?? [],
                        ids: plan?.helperIDs ?? [],
                        fallback: plan?.helpers ?? [],
                        onChange: { ids, contacts in
                            care?.contacts = contacts
                            plan?.helperIDs = ids
                            try? context.save()
                        }
                    )
                    SharedContactEditor(
                        title: "5 · Professionnels et urgences",
                        role: .therapist,
                        contacts: care?.contacts ?? [],
                        ids: plan?.professionalIDs ?? [],
                        fallback: plan?.professionals ?? [],
                        onChange: { ids, contacts in
                            care?.contacts = contacts
                            plan?.professionalIDs = ids
                            try? context.save()
                        }
                    )
                    StringListEditor(title: "6 · Rendre mon environnement sûr", systemImage: "lock.shield", items: binding(for: \.safeEnvironment))
                    messageBlock
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Palette.background)
        .navigationTitle("Ça ne va pas")
        .navigationBarTitleDisplayMode(.large)
        .task {
            plan = try? SafetyPlan.findOrCreate(in: context)
            care = try? CarePlan.findOrCreate(in: context)
        }
    }

    private func header(_ plan: SafetyPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mon plan de sécurité")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.ink)
            if let date = plan.reviewedAt {
                Text("Relu avec ma psy le \(date.formatted(.dateTime.day().month(.wide).locale(French.locale)))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            } else {
                Button("Marquer relu aujourd'hui") {
                    plan.reviewedAt = .now
                    try? context.save()
                }
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private struct CallTarget: Identifiable {
        let id = UUID()
        let title: String
        let digits: String
    }

    private func callButtons(_ plan: SafetyPlan) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(callTargets(plan)) { target in
                if let url = URL(string: "tel:\(target.digits)") {
                    Link(destination: url) {
                        Text(target.title)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Palette.surface, in: Capsule())
                    }
                }
            }
        }
    }

    private func callTargets(_ plan: SafetyPlan) -> [CallTarget] {
        LockCalls.targets(plan: care ?? cares.first, safety: plan).map {
            CallTarget(title: $0.title, digits: $0.digits)
        }
    }

    private var messageBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Écrire à quelqu'un")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            TextField("Message", text: $message, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if let person = (care?.contacts ?? []).first(where: { plan?.helperIDs.contains($0.id) == true })
                ?? plan?.helpers.first,
               let url = smsURL(person.digits) {
                Link("Écrire à \(person.name), c'est toi qui envoies", destination: url)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
            }
            Text("Rien ne part sans toi.")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)
        }
    }

    private func smsURL(_ digits: String) -> URL? {
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "sms:\(digits)")
        components?.queryItems = [URLQueryItem(name: "body", value: message)]
        return components?.url
    }

    private func binding<Value>(for keyPath: ReferenceWritableKeyPath<SafetyPlan, Value>) -> Binding<Value> {
        Binding(
            get: { plan?[keyPath: keyPath] ?? emptyValue() },
            set: {
                plan?[keyPath: keyPath] = $0
                try? context.save()
            }
        )
    }

    private func emptyValue<Value>() -> Value {
        if Value.self == [String].self { return [String]() as! Value }
        if Value.self == [Contact].self { return [Contact]() as! Value }
        fatalError("type non géré")
    }
}

/// Liste de textes libres, éditable : ajouter, supprimer.
struct StringListEditor: View {
    let title: String
    var systemImage: String? = nil
    @Binding var items: [String]
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title).font(.headline)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .foregroundStyle(Palette.ink)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button {
                        items.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("Ajouter", text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Button("OK", action: add)
                    .foregroundStyle(Palette.ink)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func add() {
        let word = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        items.append(word)
        draft = ""
    }
}

/// Contacts de la liste unique, reliés au plan de sécurité par identifiant.
struct SharedContactEditor: View {
    let title: String
    var role: ContactRole
    var contacts: [Contact]
    var ids: [UUID]
    var fallback: [Contact]
    var onChange: ([UUID], [Contact]) -> Void
    @State private var name = ""
    @State private var phone = ""

    private var shown: [Contact] {
        let resolved = ids.compactMap { id in contacts.first { $0.id == id } }
        return resolved.isEmpty ? fallback : resolved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(shown) { contact in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                        Text(contact.phone).font(.caption).foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    if let url = URL(string: "tel:\(contact.digits)"), !contact.digits.isEmpty {
                        Link("Appeler", destination: url).foregroundStyle(Palette.ink)
                    }
                    Button {
                        remove(contact)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(spacing: 8) {
                TextField("Nom", text: $name)
                TextField("Téléphone", text: $phone)
                    .keyboardType(.phonePad)
                Button("Ajouter ce contact", action: add)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !phone.isEmpty else { return }
        var nextContacts = contacts
        var nextIDs = ids.isEmpty ? fallback.map(\.id) : ids
        if let existing = nextContacts.first(where: { $0.digits == phone.filter({ $0.isNumber || $0 == "+" }) && !$0.digits.isEmpty }) {
            if !nextIDs.contains(existing.id) { nextIDs.append(existing.id) }
        } else {
            let contact = Contact(name: trimmed, phone: phone, role: role)
            nextContacts.append(contact)
            nextIDs.append(contact.id)
        }
        onChange(nextIDs, nextContacts)
        name = ""
        phone = ""
    }

    private func remove(_ contact: Contact) {
        var nextIDs = ids.isEmpty ? shown.map(\.id) : ids
        nextIDs.removeAll { $0 == contact.id }
        onChange(nextIDs, contacts)
    }
}

/// Liste de contacts (nom + téléphone), éditable, avec appel et écriture.
struct ContactListEditor: View {
    let title: String
    @Binding var contacts: [Contact]
    var message: String = ""
    @State private var name = ""
    @State private var phone = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)

            ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).foregroundStyle(Palette.ink)
                        Text(contact.phone).font(.caption).foregroundStyle(Palette.inkMuted)
                    }
                    Spacer()
                    if let url = URL(string: "tel:\(contact.digits)"), !contact.digits.isEmpty {
                        Link("Appeler", destination: url).foregroundStyle(Palette.ink)
                    }
                    Button {
                        contacts.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 8) {
                TextField("Nom", text: $name)
                TextField("Téléphone", text: $phone)
                    .keyboardType(.phonePad)
                Button("Ajouter ce contact", action: add)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !phone.isEmpty else { return }
        contacts.append(Contact(name: trimmed, phone: phone))
        name = ""
        phone = ""
    }
}
