import FamilyControls
import SwiftUI

struct TargetSelectionButton: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    let prominent: Bool

    var body: some View {
        baseButton
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: isPickerPresented) { _, presented in
                guard !presented else { return }
                Task {
                    await model.saveSelection(selection)
                }
            }
    }

    @ViewBuilder
    private var baseButton: some View {
        let button = Button {
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

        if prominent {
            button
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(AppTheme.steel)
        }
    }
}
