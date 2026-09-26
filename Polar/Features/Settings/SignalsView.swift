import SwiftUI

/// Réglage des signaux (10.2) : un interrupteur et des seuils par signal, fixés avec ta psy.
struct SignalsView: View {
    @Environment(Preferences.self) private var preferences
    @State private var newKind = AlertRule.Kind.shortSleep
    @State private var threshold = ""
    @State private var span = ""
    @State private var stage = PlanStage.early
    @State private var notifies = false

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Text("Rien n'est pré-rempli. Un signal montre un fait, jamais un risque calculé.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            }

            Section("Signaux actifs") {
                if preferences.alertRules.isEmpty {
                    Text("Aucun signal pour l'instant.")
                        .foregroundStyle(Palette.inkMuted)
                }
                ForEach($preferences.alertRules) { $rule in
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $rule.isOn) {
                            Text("\(rule.kind.label) \(formatted(rule.threshold)) · \(rule.span) j")
                        }
                        .tint(Palette.ink)
                        Toggle("Me prévenir", isOn: $rule.notifies)
                            .tint(Palette.ink)
                            .font(.subheadline)
                    }
                    .onChange(of: rule.isOn) { _, _ in preferences.save() }
                    .onChange(of: rule.notifies) { _, _ in preferences.save() }
                }
                .onDelete { offsets in
                    preferences.alertRules.remove(atOffsets: offsets)
                    preferences.save()
                }
            }

            Section("Ajouter un signal") {
                Picker("Signal", selection: $newKind) {
                    ForEach(AlertRule.Kind.allCases) { Text($0.label).tag($0) }
                }
                TextField(newKind.thresholdHint, text: $threshold)
                    .keyboardType(.decimalPad)
                TextField("Nombre de jours", text: $span)
                    .keyboardType(.numberPad)
                Picker("Palier du plan", selection: $stage) {
                    ForEach(PlanStage.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Me prévenir", isOn: $notifies).tint(Palette.ink)
                Button("Ajouter", action: add)
                    .foregroundStyle(Palette.ink)
            }
        }
        .navigationTitle("Signaux")
        .tint(Palette.ink)
    }

    private func add() {
        guard let value = Double(threshold.replacingOccurrences(of: ",", with: ".")),
              let days = Int(span), days > 0 else { return }
        let rule = AlertRule(
            kind: newKind,
            threshold: value,
            span: days,
            stage: stage.rawValue,
            isOn: true,
            notifies: notifies
        )
        preferences.alertRules.append(rule)
        preferences.save()
        threshold = ""
        span = ""
        notifies = false
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
