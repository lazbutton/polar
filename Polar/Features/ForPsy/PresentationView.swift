import SwiftUI

/// Plein écran, gros caractères, bloc par bloc. Terminé pour sortir.
struct PresentationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    ForEach(router.slides) { block in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(block.title)
                                .font(.title.weight(.semibold))
                                .foregroundStyle(Palette.inkMuted)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(block.lines, id: \.self) { line in
                                Text(line)
                                    .font(.title2)
                                    .foregroundStyle(Palette.ink)
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.background)
            .navigationTitle("Montrer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
        }
        .tint(Palette.ink)
    }
}
