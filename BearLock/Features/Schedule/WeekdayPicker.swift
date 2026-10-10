import BearLockCore
import SwiftUI

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let isSelected = selection.contains(weekday)

                Button {
                    if isSelected {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(weekday.shortName(locale: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppTheme.snow : AppTheme.navy.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(isSelected ? AppTheme.navy : Color.secondary.opacity(0.10), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppTheme.navy : Color.secondary.opacity(0.28), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accessibilityName(for: weekday)))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("weekday-\(weekday.rawValue)")
            }
        }
    }

    private func accessibilityName(for weekday: Weekday) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.weekdaySymbols[weekday.rawValue - 1]
    }
}
