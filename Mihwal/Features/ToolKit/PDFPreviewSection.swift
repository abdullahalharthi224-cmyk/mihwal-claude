import CoreGraphics
import SwiftUI

/// Live preview of a decorated page (made by the tool's own pipeline) and the
/// "links/forms will be flattened" warning shown before running.
struct PDFPreviewSection: View {
    let preview: CGImage?
    let isLocked: Bool
    let hasInteractiveContent: Bool

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 300

    var body: some View {
        Section {
            if let preview {
                Image(decorative: preview, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .padding(.vertical, DS.Spacing.xs)
                    .accessibilityLabel(Text("Preview of the page as it will be saved"))
            } else if isLocked {
                Label("Enter the password to see a preview.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        } header: {
            Text("Preview")
        } footer: {
            Label {
                Text(hasInteractiveContent
                     ? LocalizedStringKey("This PDF has links, form fields or comments. They will become part of the page (flattened) and stop working.")
                     : LocalizedStringKey("Pages are redrawn: any links or form fields would become part of the page (flattened)."))
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(hasInteractiveContent ? Color.orange : Color.secondary)
        }
    }
}
