import SwiftUI

struct ScheduleDatePicker: View {
    let title: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(title))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("schedule-date-label-\(title)")
                if displayedComponents.contains(.date) {
                    input(.date, unit: "Calendar date")
                }
                if displayedComponents.contains(.hourAndMinute) {
                    input(.hourAndMinute, unit: "Time")
                }
            }
        } else {
            DatePicker(LocalizedStringKey(title), selection: $selection, displayedComponents: displayedComponents)
                .datePickerStyle(.compact)
        }
    }

    private func input(_ components: DatePickerComponents, unit: String) -> some View {
        DatePicker(LocalizedStringKey(title), selection: $selection, displayedComponents: components)
            .datePickerStyle(.compact)
            .labelsHidden()
            .accessibilityLabel(Text(LocalizedStringKey(title)) + Text(", ") + Text(LocalizedStringKey(unit)))
    }
}
