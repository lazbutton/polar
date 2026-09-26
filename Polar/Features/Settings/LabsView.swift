import SwiftData
import SwiftUI

/// Analyses (ex. lithémie), saisies telles quelles par le laboratoire, sans interprétation.
struct LabsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LabResult.date, order: .reverse) private var labs: [LabResult]

    @State private var name = ""
    @State private var value = ""
    @State private var unit = ""
    @State private var date = Date.now

    var body: some View {
        Form {
            Section("Ajouter une analyse") {
                TextField("Nom (ex. Lithémie)", text: $name)
                TextField("Valeur", text: $value)
                    .keyboardType(.decimalPad)
                TextField("Unité (ex. mmol/L)", text: $unit)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Button("Enregistrer", action: add)
                    .foregroundStyle(Palette.ink)
            }
            Section("Historique") {
                if labs.isEmpty {
                    Text("Aucune analyse.").foregroundStyle(Palette.inkMuted)
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
            }
        }
        .navigationTitle("Analyses")
        .tint(Palette.ink)
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let number = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
        let lab = LabResult(name: trimmed, value: number, unit: unit, date: date)
        context.insert(lab)
        try? context.save()
        name = ""
        value = ""
        unit = ""
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
