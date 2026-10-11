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
        let headingLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        VStack(alignment: .leading, spacing: 10) {
            headingLayout {
                Text("Duration")
                    .font(.headline)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
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
                    HStack(spacing: 8) { presetButtons }
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
            let button = Button {
                minutes = Double(preset)
            } label: {
                Text(L10n.format("%d min", preset))
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .controlSize(.large)
            .accessibilityLabel(Text(L10n.format("%d min", preset)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("duration-preset-\(preset)")

            if isSelected {
                button
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.navy)
                    .foregroundStyle(AppTheme.snow)
            } else {
                button
                    .buttonStyle(.bordered)
                    .tint(AppTheme.steel)
                    .foregroundStyle(AppTheme.navy)
            }
        }
    }
}
