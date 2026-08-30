import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: BearLockAppModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                BearStateVisual(state: .sleeping)
                    .frame(maxWidth: 280)
                    .shadow(color: AppTheme.navy.opacity(0.12), radius: 16, y: 10)

                BrandLockup(
                    subtitle: "Choose apps. Set a time. Keep the lock.",
                    compact: false
                )

                Text("Selected apps stay locked until the scheduled end time.")
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

                TargetSelectionButton(prominent: false)
            }
            .controlSize(.large)

            Text("Selections and schedules stay on this device. No accounts, cloud sync, ads, analytics, or tracking.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.navy.opacity(0.58))

            Spacer()
        }
        .padding(24)
    }
}
