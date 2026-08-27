import FamilyControls
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image("BrandAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 38))
                    .shadow(color: AppTheme.navy.opacity(0.12), radius: 16, y: 10)

                BrandLockup(
                    subtitle: "Disappear for a while.",
                    compact: false
                )

                Text("Quietly hibernate selected apps until the chosen time.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.navy.opacity(0.72))
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await model.requestAuthorization()
                    }
                } label: {
                    Label("Allow Screen Time access", systemImage: "hourglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)

                Button {
                    isPickerPresented = true
                } label: {
                    Label("Select blocked apps", systemImage: "app.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.steel)
            }
            .controlSize(.large)

            Text("Selections are stored on device and in the App Group container. The MVP does not use accounts or cloud sync.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.navy.opacity(0.58))

            Spacer()
        }
        .padding(24)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: isPickerPresented) { _, presented in
            guard !presented else { return }
            Task {
                await model.saveSelection(selection)
            }
        }
    }
}
