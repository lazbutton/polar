import SwiftUI

/// Jauge Énergie de -2 à +2, 0 = habituelle. Affichée en `Ink` : c'est une mesure, pas un pôle.
struct EnergyRow: View {
    let title: String
    var yesterday: Int? = nil
    /// -2…+2, ou nil tant que rien n'est noté.
    @Binding var value: Int?

    private let steps = [-2, -1, 0, 1, 2]
    private let labels: [Int: String] = [
        -2: "bien plus basse",
        -1: "plus basse",
        0: "habituelle",
        1: "plus haute",
        2: "bien plus haute",
    ]

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(steps, id: \.self) { step in
                        Button {
                            value = step
                        } label: {
                            ZStack {
                                if step == yesterday, step != value {
                                    Circle()
                                        .strokeBorder(Palette.ink.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .frame(width: 32, height: 32)
                                }
                                marker(for: step)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(title), \(labels[step] ?? "")")
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let width = max(proxy.size.width / CGFloat(steps.count), 1)
                            let index = min(max(Int(gesture.location.x / width), 0), steps.count - 1)
                            value = steps[index]
                        }
                )
            }
            .frame(width: 176, height: 44)
        }
        .sensoryFeedback(.selection, trigger: value)
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value.map { labels[$0] ?? "" } ?? "non noté")
        .accessibilityAdjustableAction { direction in
            let current = value ?? 0
            switch direction {
            case .increment: value = min(current + 1, 2)
            case .decrement: value = max(current - 1, -2)
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private func marker(for step: Int) -> some View {
        let selected = step == value
        if step == 0 {
            Text("=")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Palette.background : Palette.ink)
                .frame(width: 24, height: 24)
                .background(selected ? Palette.ink : .clear, in: Circle())
                .overlay(Circle().strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: 1.5))
        } else {
            Circle()
                .fill(selected ? Palette.ink : .clear)
                .overlay(Circle().strokeBorder(selected ? Palette.ink : Palette.hairline, lineWidth: 1.5))
                .frame(width: 24, height: 24)
        }
    }

    static func word(_ value: Int?) -> String {
        switch value {
        case -2: "bien plus basse"
        case -1: "plus basse"
        case 0: "="
        case 1: "plus haute"
        case 2: "bien plus haute"
        default: "—"
        }
    }
}
