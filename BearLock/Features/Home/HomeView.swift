import BearLockCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var composerMode: LockComposerMode = .now

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if let activeLock = model.lockState.activeLock, activeLock.isActive(at: Date()) {
                    ActiveLockView(activeLock: activeLock)
                } else {
                    LockComposerView(mode: $composerMode)
                }

                ScheduledLockListView()
            }
            .padding(20)
        }
        .navigationTitle("Bear Lock")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BearDenArt(compact: true)
                .frame(width: 116, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text("Do not wake the bear.")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
    }

    private var summaryText: String {
        if model.lockState.targetSelections.isEmpty {
            return "まずはブロック対象アプリを選びます。"
        }
        return model.lockState.targetSelections.last?.displayName ?? "Selected apps"
    }
}
