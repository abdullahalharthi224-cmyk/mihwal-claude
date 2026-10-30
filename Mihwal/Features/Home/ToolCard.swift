import SwiftUI

struct ToolCard: View {
    let tool: ToolDescriptor
    let isFavorite: Bool
    /// Two-column layout: titles stay on one line and subtitles reserve two lines,
    /// so every card in a row has the same height.
    var isCompact = true

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .top) {
                ToolIcon(symbol: tool.symbol, tint: tool.category.tint, baseSize: DS.Size.cardIcon)
                Spacer(minLength: 0)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(isCompact ? 1 : nil)
                    .minimumScaleFactor(0.85)
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isCompact ? 2 : 6, reservesSpace: isCompact)
            }
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(DS.Spacing.s)
        .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isFavorite ? Text("Favorite") : Text(verbatim: ""))
        .accessibilityHint(Text("Opens the tool"))
    }
}

struct RecentChip: View {
    let tool: ToolDescriptor

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ToolIcon(symbol: tool.symbol, tint: tool.category.tint, baseSize: DS.Size.chipIcon)
            Text(tool.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.leading, 6)
        .padding(.trailing, DS.Spacing.s)
        .background(DS.Palette.card, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
