import SwiftData
import SwiftUI

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \LabResult.date, order: .reverse) private var labs: [LabResult]
    @Query private var safeties: [SafetyPlan]
    @State private var plan: CarePlan?

    private var activeMeds: [Medication] { medications.filter(\.isActive) }
    private var archivedMeds: [Medication] { medications.filter { !$0.isActive } }
    private var safety: SafetyPlan? { safeties.first }
    private var isEmpty: Bool {
        guard let plan else { return true }
        return plan.signs.isEmpty && plan.contacts.isEmpty && activeMeds.isEmpty && preferences.alertRules.isEmpty
    }

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            if let date = plan?.reviewedAt {
                Section {
                    Text("Relu avec ma psy le \(date.formatted(.dateTime.day().month(.wide).locale(French.locale)))")
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            Section {
                safetyCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if isEmpty {
                Section {
                    Text("Ton plan se remplit avec ta psy. Commence par Ça ne va pas.")
                        .foregroundStyle(Palette.inkMuted)
                    Button("Remplir Ça ne va pas") { router.push(.safetyPlan) }
                }
            }

            Section {
                ForEach(Pole.allCases) { pole in
                    let count = plan?.signs.filter { $0.pole == pole }.count ?? 0
                    Button {
                        router.push(.pole(pole, stage: nil))
                    } label: {
                        HStack {
                            Text(pole.label)
                            Spacer()
                            Text("\(count) signe\(count > 1 ? "s" : "")")
                                .foregroundStyle(Palette.inkMuted)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
                if let plan, !plan.unsortedSigns.isEmpty {
                    Button {
                        router.push(.toClassify)
                    } label: {
                        HStack {
                            Text("À classer")
                            Spacer()
                            Text("\(plan.unsortedSigns.count)")
                                .foregroundStyle(Palette.inkMuted)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
            } header: {
                Text("Prévenir").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                ForEach(activeMeds) { medication in
                    Button {
                        router.push(.medication(medication.persistentModelID))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(medication.name)
                                Text("\(medication.dose) · \(medication.slot)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.inkMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
                if !labs.isEmpty {
                    Button { router.push(.labResults) } label: {
                        HStack {
                            Text("Analyses")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
                Menu("Ajouter") {
                    Button("Traitement") { router.present(.newMedication) }
                    Button("Analyse") { router.present(.newLabResult) }
                }
                if !archivedMeds.isEmpty {
                    DisclosureGroup("Archivés · \(archivedMeds.count)") {
                        ForEach(archivedMeds) { medication in
                            Button(medication.name) {
                                router.push(.medication(medication.persistentModelID))
                            }
                            .foregroundStyle(Palette.inkMuted)
                        }
                    }
                }
            } header: {
                Text("Traitement").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                if preferences.alertRules.isEmpty {
                    Text("Aucun signal. Tu les choisis avec ta psy.")
                        .foregroundStyle(Palette.inkMuted)
                }
                ForEach($preferences.alertRules) { $rule in
                    Toggle(isOn: $rule.isOn) {
                        Text(AlertPhrase.text(for: rule))
                            .font(.subheadline)
                    }
                    .tint(Palette.ink)
                    .onChange(of: rule.isOn) { _, _ in preferences.save() }
                }
                .onDelete { offsets in
                    let removed = offsets.map { preferences.alertRules[$0] }
                    preferences.alertRules.remove(atOffsets: offsets)
                    preferences.save()
                    ToastCenter.shared.show("Supprimé.") {
                        preferences.alertRules.append(contentsOf: removed)
                        preferences.save()
                    }
                }
                Button("Ajouter un signal") { router.present(.newSignal) }
            } header: {
                Text("Signaux").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                if plan?.contacts.isEmpty != false {
                    Text("Aucun contact pour l'instant.")
                        .foregroundStyle(Palette.inkMuted)
                }
                ForEach(plan?.contacts ?? []) { contact in
                    Button {
                        router.push(.contact(contact.id))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(contact.name)
                                Text(contact.phone).font(.caption).foregroundStyle(Palette.inkMuted)
                                if let role = contact.role {
                                    Text(role.label).font(.caption).foregroundStyle(Palette.inkFaint)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkFaint)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .swipeActions {
                        Button(role: .destructive) {
                            remove(contact)
                        } label: {
                            Text("Supprimer")
                        }
                    }
                }
                Button("Ajouter un contact") { router.present(.newContact) }
            } header: {
                Text("Contacts").accessibilityAddTraits(.isHeader)
            }
            .headerProminence(.increased)

            Section {
                Button {
                    router.push(.resources)
                } label: {
                    HStack {
                        Text("Ressources")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkFaint)
                    }
                }
                .foregroundStyle(Palette.ink)
            }

            if let plan {
                Section {
                    Button("Marquer comme relu aujourd'hui") {
                        plan.reviewedAt = .now
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Mon plan")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .task { plan = try? CarePlan.findOrCreate(in: context) }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { router.push(.safetyPlan) } label: {
                HStack {
                    Text("Ça ne va pas")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(Palette.ink)
            .buttonStyle(.plain)
            Text("Ma personne · Ma psy · 3114 · 15")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LockCalls.targets(plan: plan, safety: safety), id: \.title) { target in
                    if let url = URL(string: "tel:\(target.digits)") {
                        Link(destination: url) {
                            Text(target.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Palette.background, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func remove(_ contact: Contact) {
        guard let plan else { return }
        let snapshot = contact
        plan.contacts.removeAll { $0.id == contact.id }
        safety?.helperIDs.removeAll { $0 == contact.id }
        safety?.professionalIDs.removeAll { $0 == contact.id }
        try? context.save()
        ToastCenter.shared.show("Supprimé.") {
            plan.contacts.append(snapshot)
            try? context.save()
        }
    }
}

struct PolePage: View {
    var pole: Pole
    var focus: Int?
    @Environment(\.modelContext) private var context
    @State private var plan: CarePlan?

    var body: some View {
        ScrollViewReader { proxy in
            form
                .task {
                    plan = try? CarePlan.findOrCreate(in: context)
                    guard let focus else { return }
                    try? await Task.sleep(for: .milliseconds(80))
                    proxy.scrollTo(focus, anchor: .top)
                }
        }
    }

    private var form: some View {
        Form {
            if let plan {
                if plan.signs(pole: pole, stage: .early).isEmpty, plan.actions(pole: pole, stage: .early).isEmpty,
                   plan.signs(pole: pole, stage: .settled).isEmpty {
                    Section {
                        Text(pole == .up
                             ? "Quels sont tes premiers signes quand ça monte ?"
                             : "Quels sont tes premiers signes quand ça descend ?")
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                ForEach(PlanStage.allCases) { stage in
                    stageSection(plan, stage: stage)
                }
            }
        }
        .navigationTitle(pole.label)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
    }

    private func stageSection(_ plan: CarePlan, stage: PlanStage) -> some View {
        let signs = plan.signs(pole: pole, stage: stage)
        let actions = plan.actions(pole: pole, stage: stage)
        return Section {
            ForEach(signs) { sign in
                Text(sign.text)
            }
            .onDelete { offsets in
                let ids = offsets.map { signs[$0].id }
                plan.signs.removeAll { ids.contains($0.id) }
                try? context.save()
            }
            AddField(placeholder: "Ajouter un signe") { text in
                plan.signs.append(WarningSign(text: text, pole: pole, stage: stage.rawValue))
                try? context.save()
            }
            ForEach(actions) { action in
                Text(action.text).foregroundStyle(Palette.inkMuted)
            }
            .onDelete { offsets in
                let ids = offsets.map { actions[$0].id }
                plan.actions.removeAll { ids.contains($0.id) }
                try? context.save()
            }
            AddField(placeholder: "Ajouter une action") { text in
                plan.actions.append(PlanAction(text: text, pole: pole, stage: stage.rawValue))
                try? context.save()
            }
        } header: {
            Text(stage.label)
                .accessibilityAddTraits(.isHeader)
        }
        .headerProminence(.increased)
        .id(stage.rawValue)
    }
}

struct ToClassifyPage: View {
    @Environment(\.modelContext) private var context
    @State private var plan: CarePlan?

    var body: some View {
        Form {
            Section {
                Text("Ces signes viennent de la version précédente. Classe-les par pôle.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(plan?.unsortedSigns ?? []) { sign in
                    HStack {
                        Text(sign.text)
                        Spacer()
                        Menu("Classer") {
                            ForEach(Pole.allCases) { pole in
                                Button(pole.label) { classify(sign, to: pole) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("À classer")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .tint(Palette.ink)
        .task { plan = try? CarePlan.findOrCreate(in: context) }
    }

    private func classify(_ sign: WarningSign, to pole: Pole) {
        guard let plan, let index = plan.signs.firstIndex(where: { $0.id == sign.id }) else { return }
        plan.signs[index].pole = pole
        try? context.save()
    }
}

struct AddField: View {
    let placeholder: String
    let action: (String) -> Void
    @State private var draft = ""

    var body: some View {
        HStack {
            TextField(placeholder, text: $draft)
            Button("OK") {
                let word = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty else { return }
                action(word)
                draft = ""
            }
        }
    }
}
