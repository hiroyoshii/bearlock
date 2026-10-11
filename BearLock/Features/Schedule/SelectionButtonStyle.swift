import SwiftUI

struct SelectionButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .foregroundStyle(isEnabled ? (isSelected ? AppTheme.snow : AppTheme.navy) : AppTheme.navy.opacity(0.72))
            .background(
                isSelected && isEnabled ? AppTheme.navy : AppTheme.navy.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? AppTheme.navy : AppTheme.navy.opacity(0.24), lineWidth: isSelected ? 2 : 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
