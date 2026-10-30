import SwiftUI

/// Rounded, tinted square with an SF Symbol. Scales with Dynamic Type.
struct ToolIcon: View {
    let symbol: String
    let tint: Color
    @ScaledMetric private var size: CGFloat

    init(symbol: String, tint: Color, baseSize: CGFloat = DS.Size.toolIcon) {
        self.symbol = symbol
        self.tint = tint
        _size = ScaledMetric(wrappedValue: baseSize, relativeTo: .headline)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Slight shrink while pressed, like Apple's own cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringResource
    let symbol: String?
    let trailing: Trailing

    init(_ title: LocalizedStringResource, symbol: String? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.symbol = symbol
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.bold))
            Spacer(minLength: DS.Spacing.xs)
            trailing
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "Works offline" reassurance shown at the top of Home.
struct OfflineBadge: View {
    var body: some View {
        Label {
            Text("Works offline · Your files never leave your iPhone")
        } icon: {
            Image(systemName: "lock.shield.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(.thinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
