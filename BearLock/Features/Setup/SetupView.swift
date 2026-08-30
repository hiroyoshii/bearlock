import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: BearLockAppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                BearHeroArt()
                    .frame(maxWidth: 310)
                    .shadow(color: AppTheme.navy.opacity(0.12), radius: 16, y: 10)
                    .accessibilityLabel("Bear Lock")

                Text("Choose apps. Set a time. Keep the lock.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.steel)
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

                TargetSelectionButton(prominent: false)
            }
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
    }
}
