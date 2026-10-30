import SwiftUI

struct ProcessingOverlay: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.m) {
                ProgressView(value: progress) {
                    Text("Working…")
                        .font(.headline)
                } currentValueLabel: {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
            }
            .padding(DS.Spacing.l)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
            .padding(DS.Spacing.l)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
