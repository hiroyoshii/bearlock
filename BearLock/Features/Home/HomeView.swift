import BearLockCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var composerMode: LockComposerMode = .now

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if model.lockState.targetSelections.isEmpty {
                    targetSelectionPrompt
                } else {
                    selectedTargetSummary
                }

                if !hasActiveLock {
                    FrequentTargetListView()
                }

                if let activeLock = model.lockState.activeLock, activeLock.isActive(at: Date()) {
                    ActiveLockView(activeLock: activeLock)
                }

                LockComposerView(mode: $composerMode, allowsImmediateLock: !hasActiveLock)
                ScheduledLockListView()
            }
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("BrandHeaderLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 142, height: 50, alignment: .leading)
                    .accessibilityLabel("Bear Lock")
            }
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

    private var selectedTargetSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            TargetSelectionSummaryView()
            TargetSelectionButton(prominent: false)
        }
        .padding(16)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
    }

    private var hasActiveLock: Bool {
        model.lockState.activeLock?.isActive(at: Date()) == true
    }
}
