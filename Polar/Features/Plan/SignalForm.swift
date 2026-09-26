import SwiftUI

struct SignalForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Preferences.self) private var preferences
    @State private var kind: AlertRule.Kind?
    @State private var threshold = ""
    @State private var span = ""
    @State private var pole: Pole?
    @State private var stage = PlanStage.early
    @State private var showMore = false

    private let first: [AlertRule.Kind] = [.shortSleep, .sleepLate, .energyHigh, .signs]

    private var visible: [AlertRule.Kind] {
        showMore ? AlertRule.Kind.allCases : first
    }

    private var parsedThreshold: Double? {
        Double(threshold.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedSpan: Int? { Int(span) }

    private var canFinish: Bool {
        guard let kind else { return false }
        return AlertPhrase.isComplete(kind: kind, threshold: parsedThreshold, span: parsedSpan, pole: pole)
    }

    var body: some View {
        Form {
            Section {
                Text("Choisis une phrase")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(visible) { item in
                    Button {
                        kind = item
                        if pole == nil { pole = item.defaultPole }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: kind == item ? "largecircle.fill.circle" : "circle")
                            Text(AlertPhrase.text(kind: item, threshold: nil, span: nil, pole: pole))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .buttonStyle(.plain)
                    if kind == item {
                        blanks(for: item)
                    }
                }
                if !showMore {
                    Button("Autres phrases…") { showMore = true }
                }
            }
            Section {
                Picker("Quand il s'allume, ouvrir", selection: $pole) {
                    Text("Choisir").tag(Pole?.none)
                    ForEach(Pole.allCases) { item in
                        Text(item.label).tag(Optional(item))
                    }
                }
                Picker("Palier", selection: $stage) {
                    ForEach(PlanStage.allCases) { Text($0.label).tag($0) }
                }
            }
        }
        .navigationTitle("Nouveau signal")
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

    @ViewBuilder
    private func blanks(for item: AlertRule.Kind) -> some View {
        let blanks = AlertPhrase.blanks(item)
        if blanks.threshold {
            TextField(item.thresholdHint, text: $threshold)
                .keyboardType(.decimalPad)
        }
        if blanks.span {
            TextField("Nombre", text: $span)
                .keyboardType(.numberPad)
        }
        if blanks.pole {
            Picker("Pôle", selection: $pole) {
                Text("Quand ça monte").tag(Optional(Pole.up))
                Text("Quand ça descend").tag(Optional(Pole.down))
            }
        }
    }

    private func save() {
        guard let kind, canFinish else { return }
        let blanks = AlertPhrase.blanks(kind)
        let rule = AlertRule(
            kind: kind,
            threshold: blanks.threshold ? (parsedThreshold ?? 0) : 0,
            span: blanks.span ? (parsedSpan ?? 1) : (kind == .medMissed ? (parsedSpan ?? 1) : 1),
            stage: stage.rawValue,
            isOn: true,
            notifies: false,
            pole: pole ?? kind.defaultPole
        )
        preferences.alertRules.append(rule)
        preferences.save()
        dismiss()
    }
}
