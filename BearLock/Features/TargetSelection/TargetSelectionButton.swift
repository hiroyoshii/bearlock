import FamilyControls
import SwiftUI

struct TargetSelectionButton: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    let prominent: Bool

    var body: some View {
        Button {
            do {
                selection = try model.targetSelectionStore.load()
            } catch {
                selection = FamilyActivitySelection()
            }
            isPickerPresented = true
        } label: {
            Label("Select blocked apps", systemImage: "app.badge")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(prominent ? .borderedProminent : .bordered)
        .tint(prominent ? AppTheme.navy : AppTheme.steel)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: isPickerPresented) { _, presented in
            guard !presented else { return }
            Task {
                await model.saveSelection(selection)
            }
        }
    }
}
