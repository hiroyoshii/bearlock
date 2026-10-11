import BearLockCore
import SwiftUI

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { weekdayButtons }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { weekdayButtons }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: 4), spacing: 8) {
                    weekdayButtons
                }
            }
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
                if dynamicTypeSize.isAccessibilitySize {
                    Label(accessibilityName(for: weekday), systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .padding(.horizontal, 8)
                } else {
                    VStack(spacing: 4) {
                        Text(weekday.shortName(locale: locale))
                            .font(.subheadline.weight(.semibold))
                            .fixedSize()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(SelectionButtonStyle(isSelected: isSelected))
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
