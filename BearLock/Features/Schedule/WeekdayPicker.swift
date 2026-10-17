import BearLockCore
import SwiftUI

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var diameter: CGFloat = 44

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { weekdayButtons }
        } else {
            HStack(spacing: 8) { weekdayButtons }
        }
    }

    private var weekdayButtons: some View {
        ForEach(Weekday.allCases, id: \.self) { weekday in
            let isSelected = selection.contains(weekday)
            Button {
                if isSelected {
                    selection.remove(weekday)
                } else {
                    selection.insert(weekday)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(weekday.shortName(locale: locale))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppTheme.snow : AppTheme.navy.opacity(0.72))
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? diameter : nil, height: diameter)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
                        .background(isSelected ? AppTheme.navy : Color.secondary.opacity(0.10), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(isSelected ? AppTheme.navy : Color.secondary.opacity(0.28), lineWidth: 1)
                        }
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(accessibilityName(for: weekday))
                            .font(.body)
                            .foregroundStyle(AppTheme.navy)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityName(for: weekday)))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("weekday-\(weekday.rawValue)")
        }
    }

    private func accessibilityName(for weekday: Weekday) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.weekdaySymbols[weekday.rawValue - 1]
    }
}
