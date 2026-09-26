import SwiftUI

struct ScaleRow: View {
    let title: String
    let tint: Color
    @Binding var value: Int
    private let levels = ["aucun", "léger", "modéré", "sévère"]

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { level in
                        Button {
                            value = level
                        } label: {
                            Circle()
                                .fill(level == value ? tint : .clear)
                                .overlay(Circle().strokeBorder(level == value ? tint : Palette.hairline, lineWidth: 1.5))
                                .frame(width: 24, height: 24)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(title), \(levels[level])")
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let step = max(proxy.size.width / 4, 1)
                            value = min(max(Int(gesture.location.x / step), 0), 3)
                        }
                )
            }
            .frame(width: 176, height: 44)
        }
        .sensoryFeedback(.selection, trigger: value)
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(levels[min(max(value, 0), 3)])
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, 3)
            case .decrement: value = max(value - 1, 0)
            @unknown default: break
            }
        }
    }
}
