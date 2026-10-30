import SwiftUI

/// Import problems shown inside the screen (not as an alert), so they are always seen.
struct ImportErrorBanner: View {
    let error: ToolError
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline.weight(.semibold))
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(DS.Spacing.s)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
