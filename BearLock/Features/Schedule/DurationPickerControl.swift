import SwiftUI

struct DurationPickerControl: View {
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
                .accessibilityIdentifier("duration-slider")

            if !presetMinutes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(presetMinutes, id: \.self) { preset in
                        Button {
                            minutes = Double(preset)
                        } label: {
                            Text(L10n.format("%d min", preset))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Int(minutes) == preset ? AppTheme.navy : AppTheme.steel)
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
}
