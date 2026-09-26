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

struct GlassPlusButton: View {
    var tap: () -> Void
    var longPress: () -> Void

    var body: some View {
        Button(action: tap) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.ink)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in longPress() }
        )
        .accessibilityLabel("Nouveau moment")
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
            try? await Task.sleep(for: .seconds(4))
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
