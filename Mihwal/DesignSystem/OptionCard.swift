import SwiftUI

/// A rounded card that groups related options, used by tools with the scroll layout.
struct OptionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
    }
}
