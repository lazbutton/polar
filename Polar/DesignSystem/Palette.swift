import SwiftUI

enum Palette {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let hairline = Color("Hairline")
    static let ink = Color("Ink")
    static let inkMuted = Color("InkMuted")
    static let inkFaint = Color("InkFaint")
    static let elevated = Color("Elevated")
    static let depressed = Color("Depressed")
    static let irritability = Color("Irritability")
    static let anxiety = Color("Anxiety")
}

enum French {
    static let locale = Locale(identifier: "fr_FR")

    static func dayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    static func sleep(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(width: width, subviews: subviews)
        let height = rows.map { row in row.map(\.size.height).max() ?? 0 }.reduce(0) { $0 + $1 + spacing } - (rows.isEmpty ? 0 : spacing)
        return CGSize(width: width, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            let height = row.map(\.size.height).max() ?? 0
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [[(view: LayoutSubview, size: CGSize)]] {
        var rows: [[(view: LayoutSubview, size: CGSize)]] = []
        var row: [(view: LayoutSubview, size: CGSize)] = []
        var used: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if used + size.width > width, !row.isEmpty {
                rows.append(row)
                row = []
                used = 0
            }
            row.append((view, size))
            used += size.width + spacing
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }
}

struct SurfaceCard<Content: View>: View {
    var prominent = false
    var inset: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(prominent ? Palette.ink : .clear, lineWidth: prominent ? 1.5 : 0)
            }
    }
}
