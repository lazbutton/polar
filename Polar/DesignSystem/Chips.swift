import SwiftUI

struct EmotionChip: View {
    let title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(selected ? Palette.background : Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? Palette.ink : Palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Puce d'émotion : un toucher enregistre sans intensité ; appuyer puis glisser règle l'intensité.
struct IntensityChip: View {
    let title: String
    var fill: Color = Palette.surface
    /// nil = sans intensité.
    var onCommit: (Int?) -> Void

    @State private var intensity: Int?
    @State private var isAdjusting = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if isAdjusting, let intensity {
                Text("\(intensity)")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .foregroundStyle(isAdjusting ? Palette.background : Palette.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(isAdjusting ? Palette.ink : fill, in: Capsule())
        .onTapGesture { onCommit(nil) }
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { state in
                    guard case .second(true, let drag) = state else { return }
                    isAdjusting = true
                    let dx = drag?.translation.width ?? 0
                    intensity = max(0, min(10, 5 + Int((dx / 16).rounded())))
                }
                .onEnded { _ in
                    if isAdjusting { onCommit(intensity) }
                    isAdjusting = false
                    intensity = nil
                }
        )
        .animation(.snappy, value: isAdjusting)
        .sensoryFeedback(.selection, trigger: intensity)
        .sensoryFeedback(.impact(weight: .medium), trigger: isAdjusting) { _, new in new }
        .accessibilityLabel(title)
        .accessibilityHint("Touche pour noter, maintiens et glisse pour l'intensité")
    }
}

struct GlassPlusButton: View {
    var tap: () -> Void
    var longPress: () -> Void

    var body: some View {
        Button(action: tap) {
            Image(systemName: "square.and.pencil")
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.ink)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in longPress() }
        )
        .accessibilityLabel("Écrire")
        .accessibilityHint("Maintiens pour dicter")
        .accessibilityAction(named: "Dicter") { longPress() }
    }
}

@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    var message: String?
    private var undoAction: (() -> Void)?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, undo: (() -> Void)? = nil) {
        self.message = message
        undoAction = undo
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self.message = nil
            undoAction = nil
        }
    }

    func undo() {
        undoAction?()
        message = nil
        undoAction = nil
        dismissTask?.cancel()
    }
}

struct ToastOverlay: View {
    @Bindable var center: ToastCenter

    var body: some View {
        if let message = center.message {
            HStack(spacing: 12) {
                Text(message)
                    .foregroundStyle(Palette.ink)
                if center.hasUndo {
                    Button("Annuler") { center.undo() }
                        .foregroundStyle(Palette.ink)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .padding(.bottom, 88)
            .transition(.opacity)
            .sensoryFeedback(.success, trigger: message)
        }
    }
}

extension ToastCenter {
    var hasUndo: Bool { undoAction != nil }
}
