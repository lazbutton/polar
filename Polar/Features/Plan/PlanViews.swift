import SwiftData
import SwiftUI

struct CarePlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(Preferences.self) private var preferences
    @Environment(CaptureRouter.self) private var router
    @State private var plan: CarePlan?
    @State private var signDraft = ""
    @State private var helpDraft = ""
    @State private var newRuleKind = AlertRule.Kind.shortSleep
    @State private var newThreshold = ""
    @State private var newSpan = ""

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            if let plan {
                stringList("Signes précurseurs", items: plan.warningSigns, draft: $signDraft) { plan.warningSigns = $0 }
                stringList("Ce qui t'aide", items: plan.whatHelps, draft: $helpDraft) { plan.whatHelps = $0 }
                Section("Personne de confiance") {
                    TextField("Nom", text: Binding(get: { plan.trustedName ?? "" }, set: { plan.trustedName = $0.isEmpty ? nil : $0 }))
                    TextField("Téléphone", text: Binding(get: { plan.trustedPhone ?? "" }, set: { plan.trustedPhone = $0.isEmpty ? nil : $0 }))
                        .keyboardType(.phonePad)
                }
                Section("Psy") {
                    TextField("Nom", text: Binding(get: { plan.therapistName ?? "" }, set: { plan.therapistName = $0.isEmpty ? nil : $0 }))
                    TextField("Téléphone", text: Binding(get: { plan.therapistPhone ?? "" }, set: { plan.therapistPhone = $0.isEmpty ? nil : $0 }))
                        .keyboardType(.phonePad)
                }
            }
            Section {
                Text("Aucun seuil n'est fixé tant que tu ne l'écris pas avec ta psy.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                Picker("Signal", selection: $newRuleKind) {
                    ForEach(AlertRule.Kind.allCases) { Text($0.label).tag($0) }
                }
                TextField(newRuleKind == .shortSleep ? "Heures" : "Niveau, 1 à 3", text: $newThreshold)
                    .keyboardType(.decimalPad)
                TextField("Nombre de jours", text: $newSpan)
                    .keyboardType(.numberPad)
                Button("Ajouter ce signal") { addRule() }
                ForEach(preferences.alertRules) { rule in
                    Text("\(rule.kind.label) \(rule.threshold) · \(rule.span)")
                }
                .onDelete { offsets in
                    preferences.alertRules.remove(atOffsets: offsets)
                    preferences.save()
                }
            } header: {
                Text("Signaux d'alerte")
            }
            Section {
                Button("Ça ne va pas") { router.openSupport() }
            }
        }
        .navigationTitle("Mon plan")
        .task {
            plan = try? CarePlan.findOrCreate(in: context)
        }
    }

    private func stringList(_ title: String, items: [String], draft: Binding<String>, set: @escaping ([String]) -> Void) -> some View {
        Section(title) {
            ForEach(items, id: \.self) { item in
                Text(item)
            }
            .onDelete { offsets in
                var copy = items
                copy.remove(atOffsets: offsets)
                set(copy)
                try? context.save()
            }
            HStack {
                TextField("Ajouter", text: draft)
                Button("OK") {
                    let word = draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !word.isEmpty else { return }
                    set(items + [word])
                    draft.wrappedValue = ""
                    try? context.save()
                }
            }
        }
    }

    private func addRule() {
        guard let threshold = Double(newThreshold.replacingOccurrences(of: ",", with: ".")),
              let span = Int(newSpan), span > 0 else { return }
        preferences.alertRules.append(AlertRule(kind: newRuleKind, threshold: threshold, span: span))
        preferences.save()
        newThreshold = ""
        newSpan = ""
    }
}

struct SupportView: View {
    @Environment(\.modelContext) private var context
    @Query private var plans: [CarePlan]
    @State private var message = "Je ne vais pas très bien. Tu peux me rappeler ?"

    private var plan: CarePlan? { plans.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let helps = plan?.whatHelps, !helps.isEmpty {
                    Text("Ce qui t'aide")
                        .font(.headline)
                    ForEach(helps, id: \.self) { Text($0) }
                }
                if let phone = plan?.trustedPhone {
                    Link("Appeler \(plan?.trustedName ?? "ta personne de confiance")", destination: URL(string: "tel:\(digits(phone))")!)
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if let url = smsURL(phone: phone) {
                        Link("Écrire, c'est toi qui envoies", destination: url)
                    }
                }
                if let phone = plan?.therapistPhone {
                    Link("Appeler \(plan?.therapistName ?? "ta psy")", destination: URL(string: "tel:\(digits(phone))")!)
                }
                Link("3114, prévention du suicide, 24 h/24", destination: URL(string: "tel:3114")!)
                Link("15, urgence médicale", destination: URL(string: "tel:15")!)
            }
            .font(.body)
            .foregroundStyle(Palette.ink)
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("Ça ne va pas")
        .navigationBarTitleDisplayMode(.large)
    }

    private func digits(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }

    private func smsURL(phone: String) -> URL? {
        var components = URLComponents(string: "sms:\(digits(phone))")
        components?.queryItems = [URLQueryItem(name: "body", value: message)]
        return components?.url
    }
}
