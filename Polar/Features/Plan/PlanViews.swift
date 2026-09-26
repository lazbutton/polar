import SwiftData
import SwiftUI

/// Mon plan : prévention des rechutes, par pôle et par palier.
struct CarePlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @State private var plan: CarePlan?

    var body: some View {
        Form {
            if let plan {
                Section {
                    if let date = plan.reviewedAt {
                        Text("Relu le \(date.formatted(.dateTime.day().month(.wide).locale(French.locale)))")
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Button("Marquer relu aujourd'hui") {
                        plan.reviewedAt = .now
                        try? context.save()
                    }
                }

                ForEach(Pole.allCases) { pole in
                    ForEach(PlanStage.allCases) { stage in
                        poleStageSection(plan, pole: pole, stage: stage)
                    }
                }

                if !plan.unsortedSigns.isEmpty {
                    unsortedSection(plan)
                }

                contactsSection(plan)
            }

            signalsSection

            Section {
                NavigationLink("Plan de sécurité", value: AppRoute.safetyPlan)
            }
        }
        .navigationTitle("Mon plan")
        .tint(Palette.ink)
        .task { plan = try? CarePlan.findOrCreate(in: context) }
    }

    private func poleStageSection(_ plan: CarePlan, pole: Pole, stage: PlanStage) -> some View {
        Section("\(pole.label) · \(stage.label)") {
            let signs = plan.signs(pole: pole, stage: stage)
            ForEach(signs) { sign in
                Text(sign.text)
            }
            .onDelete { offsets in
                let ids = offsets.map { signs[$0].id }
                plan.signs.removeAll { ids.contains($0.id) }
                try? context.save()
            }
            addField("Ajouter un signe") { text in
                plan.signs.append(WarningSign(text: text, pole: pole, stage: stage.rawValue))
                try? context.save()
            }

            let actions = plan.actions(pole: pole, stage: stage)
            ForEach(actions) { action in
                Text(action.text)
                    .foregroundStyle(Palette.inkMuted)
            }
            .onDelete { offsets in
                let ids = offsets.map { actions[$0].id }
                plan.actions.removeAll { ids.contains($0.id) }
                try? context.save()
            }
            addField("Ajouter une action") { text in
                plan.actions.append(PlanAction(text: text, pole: pole, stage: stage.rawValue))
                try? context.save()
            }
        }
    }

    private func unsortedSection(_ plan: CarePlan) -> some View {
        Section("À classer") {
            Text("Ces signes viennent de la version précédente. Classe-les par pôle.")
                .font(.caption)
                .foregroundStyle(Palette.inkMuted)
            ForEach(plan.unsortedSigns) { sign in
                HStack {
                    Text(sign.text)
                    Spacer()
                    Menu("Classer") {
                        ForEach(Pole.allCases) { pole in
                            Button(pole.label) { classify(sign, to: pole, in: plan) }
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
            }
        }
    }

    private func contactsSection(_ plan: CarePlan) -> some View {
        Section("Contacts") {
            ForEach(plan.contacts) { contact in
                VStack(alignment: .leading) {
                    Text(contact.name)
                    Text(contact.phone).font(.caption).foregroundStyle(Palette.inkMuted)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { plan.contacts[$0].id }
                plan.contacts.removeAll { ids.contains($0.id) }
                try? context.save()
            }
            NavigationLink("Plan de sécurité et contacts d'urgence", value: AppRoute.safetyPlan)
        }
    }

    private var signalsSection: some View {
        Section {
            NavigationLink("Régler les signaux", value: AppRoute.settings)
            Text("Aucun seuil n'est fixé tant que tu ne l'écris pas avec ta psy.")
                .font(.caption)
                .foregroundStyle(Palette.inkMuted)
            ForEach(preferences.alertRules) { rule in
                Text("\(rule.kind.label) \(formatted(rule.threshold)) · \(rule.span) j")
                    .foregroundStyle(rule.isOn ? Palette.ink : Palette.inkMuted)
            }
        } header: {
            Text("Signaux d'alerte")
        }
    }

    private func classify(_ sign: WarningSign, to pole: Pole, in plan: CarePlan) {
        guard let index = plan.signs.firstIndex(where: { $0.id == sign.id }) else { return }
        plan.signs[index].pole = pole
        try? context.save()
    }

    private func addField(_ placeholder: String, action: @escaping (String) -> Void) -> some View {
        AddField(placeholder: placeholder, action: action)
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Champ d'ajout avec un bouton, réutilisé pour signes et actions.
private struct AddField: View {
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
            .foregroundStyle(Palette.ink)
        }
    }
}
