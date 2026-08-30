import BearLockCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var composerMode: LockComposerMode = .now

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if model.lockState.targetSelections.isEmpty {
                    targetSelectionPrompt
                }

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
        VStack(alignment: .leading, spacing: 10) {
            BearHeroArt()
                .frame(maxWidth: .infinity)
                .background(AppTheme.snow)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(AppTheme.steel)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distractions stay outside.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.navy)
                    summaryView
                        .font(.caption)
                        .foregroundStyle(AppTheme.navy.opacity(0.62))
                }
                Spacer()
            }
            .padding(12)
            .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var targetSelectionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select blocked apps first.")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)
            Text("Choose at least one target")
                .font(.subheadline)
                .foregroundStyle(AppTheme.navy.opacity(0.62))
            TargetSelectionButton(prominent: true)
                .controlSize(.large)
        }
        .padding(16)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var summaryView: some View {
        if model.lockState.targetSelections.isEmpty {
            Text("Select blocked apps first.")
        } else {
            Text(model.lockState.targetSelections.last?.displayName ?? L10n.string("Selected apps"))
        }
    }
}
