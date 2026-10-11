import SwiftUI

struct DurationPickerControl: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var minutes: Double
    let minimumMinutes: Double
    let maximumMinutes: Double

    private var presetMinutes: [Int] {
        [15, 30, 60, 120]
            .filter { Double($0) >= minimumMinutes && Double($0) <= maximumMinutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Duration")
                    .font(.headline)
                Spacer()
                Text(L10n.format("%d min", Int(minutes)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.navy)
            }

            Slider(value: $minutes, in: minimumMinutes...maximumMinutes, step: 5)
                .tint(AppTheme.navy)
                .accessibilityLabel("Duration")
                .accessibilityValue(Text(L10n.format("%d min", Int(minutes))))
                .accessibilityIdentifier("duration-slider")

            if !presetMinutes.isEmpty {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 8) { presetButtons }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { presetButtons }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            presetButtons
                        }
                    }
                }
            }

            if minimumMinutes >= 15 {
                Text("Locks start at 15 minutes or longer.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            }
        }
    }

    private var presetButtons: some View {
        ForEach(presetMinutes, id: \.self) { preset in
            let isSelected = minutes == Double(preset)
            Button {
                minutes = Double(preset)
            } label: {
                Label(L10n.format("%d min", preset), systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(SelectionButtonStyle(isSelected: isSelected))
            .accessibilityLabel(Text(L10n.format("%d min", preset)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("duration-preset-\(preset)")
        }
    }
}
