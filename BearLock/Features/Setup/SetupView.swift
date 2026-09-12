import SwiftUI

struct SetupView: View {
    @AppStorage("hasSeenIntroduction") private var hasSeenIntroduction = false

    var body: some View {
        ScrollView {
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
                Text("Once started, the lock cannot be ended early. It ends automatically at the chosen time.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    hasSeenIntroduction = true
                } label: {
                    Label("Get started", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)


            }
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
        }
    }
}
