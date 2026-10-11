import SwiftUI

struct SelectionButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        return configuration.label
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .foregroundStyle(isEnabled ? (isSelected ? AppTheme.snow : AppTheme.navy) : AppTheme.navy.opacity(0.72))
            .background(
                isSelected && isEnabled
                    ? AppTheme.navy.opacity(configuration.isPressed ? 0.86 : 1)
                    : AppTheme.navy.opacity(configuration.isPressed ? 0.1 : 0.04),
                in: shape
            )
            .background(AppTheme.snow, in: shape)
            .overlay {
                shape
                    .stroke(isSelected ? AppTheme.navy : AppTheme.navy.opacity(0.24), lineWidth: isSelected ? 2 : 1)
            }
    }
}
