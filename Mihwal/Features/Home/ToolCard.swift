import SwiftUI

struct ToolCard: View {
    let tool: ToolDescriptor
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top) {
                ToolIcon(symbol: tool.symbol, tint: tool.category.tint)
                Spacer(minLength: 0)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(tool.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DS.Spacing.m)
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
