import BearLockCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var composerMode: LockComposerMode
    let launchDestination: ShieldLaunchDestination?
    let onWake: (ActiveLock) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if model.monitoringUpdateFailed {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Monitoring could not be updated", systemImage: "exclamationmark.triangle")
                                    .font(.headline)
                                Text("Your schedules are saved. Scheduled blocking may not work until monitoring is updated.")
                                Button("Retry") { Task { await model.refresh() } }
                                    .disabled(model.isRefreshing)
                                    .accessibilityIdentifier("monitoring-retry")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
                        }
                        if model.authorizationStatus != .approved && (model.authorizationStatus == .denied || !model.lockState.targetSelections.isEmpty || !model.lockState.rules.isEmpty) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Screen Time access is unavailable. Blocking may not be active.")
                                Button("Review access") { Task { await model.requestAuthorization() } }
                                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                            }
                            .padding().background(AppTheme.snow)
                        }
                        if model.lockState.selectedTarget == nil {
                            targetSelectionPrompt
                        } else {
                            selectedTargetSummary
                        }

                        LockComposerView(mode: $composerMode, allowsImmediateLock: !hasActiveLock)
                        ScheduledLockListView(onWake: onWake)
                            .id("configured-locks")
                    }
                    .padding(20)
                }
                .onChange(of: launchDestination, initial: true) { _, destination in
                    guard destination == .dailyAllowance else { return }
                    composerMode = .always
                    withAnimation { proxy.scrollTo("configured-locks", anchor: .top) }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    init(
        launchDestination: ShieldLaunchDestination? = nil,
        initialComposerMode: LockComposerMode = .now,
        onWake: @escaping (ActiveLock) -> Void
    ) {
        self.launchDestination = launchDestination
        _composerMode = State(initialValue: initialComposerMode)
        self.onWake = onWake
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
        model.activeLock?.isActive(at: Date()) == true
    }
}
