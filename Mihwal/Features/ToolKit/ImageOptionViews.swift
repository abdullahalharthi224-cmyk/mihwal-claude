import SwiftUI

/// "Remove location" switch shared by every image tool. On by default.
struct LocationSection: View {
    @Binding var removeLocation: Bool

    var body: some View {
        Section {
            Toggle(isOn: $removeLocation) {
                Label("Remove location", systemImage: "location.slash")
            }
        } footer: {
            Text("Photos can store where they were taken. Removing it keeps that private. Camera details are kept.")
        }
    }
}

/// 30–100 % quality slider for JPG and HEIC.
struct QualitySlider: View {
    @Binding var quality: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("Quality")
                Spacer()
                Text(quality, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $quality, in: 0.3...1, step: 0.05) {
                Text("Quality")
            } minimumValueLabel: {
                Text("Smaller").font(.caption)
            } maximumValueLabel: {
                Text("Sharper").font(.caption)
            }
        }
    }
}
