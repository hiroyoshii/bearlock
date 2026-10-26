import SwiftUI
import BearLockCore

struct RootView: View {
    @AppStorage("hasSeenIntroduction") private var hasSeenIntroduction = false
    @EnvironmentObject private var model: BearLockAppModel
    @EnvironmentObject private var wakePurchaseStore: WakePurchaseStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationPath = NavigationPath()
    @State private var wakeTarget: ActiveLock?
    @State private var showsWakeResult = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if model.readStatus == .failed {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Saved data could not be read", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text("Your data has not been replaced. Retry to load your targets and schedules.")
                            Button("Retry") { Task { await model.refresh() } }
                                .disabled(model.isRefreshing)
                                .accessibilityIdentifier("storage-retry")
                            NavigationLink("Diagnostics") { DebugDiagnosticsView() }
                                .accessibilityIdentifier("storage-diagnostics")
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("storage-load-error")
                } else if model.hasLoadedInitialState {
                    if !hasSeenIntroduction && model.authorizationStatus == .unknown && model.lockState.targetSelections.isEmpty && model.lockState.rules.isEmpty {
                        SetupView()
                    } else {
                        HomeView { wakeTarget = $0 }
                    }
                } else {
                    ProgressView()
                        .tint(AppTheme.navy)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .alert("Bear Lock", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    model.lastErrorMessage = nil
                }
            } message: {
                Text(model.lastErrorMessage ?? "")
            }
        }
        .task {
            await activate()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await activate()
            }
        }
        .onChange(of: model.wakeCompletionID) { _, completionID in
            if completionID != nil { showsWakeResult = true }
        }
        .wakeOptionsDialog(target: $wakeTarget)
        .alert("Bear Lock", isPresented: wakePurchaseMessageBinding) {
            Button("OK", role: .cancel) {
                wakePurchaseStore.clearResult()
            }
        } message: {
            Text(wakePurchaseStore.message ?? "")
        }
        .sheet(isPresented: $showsWakeResult, onDismiss: wakePurchaseStore.clearResult) {
            WakeResultView()
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )
    }

    private var wakePurchaseMessageBinding: Binding<Bool> {
        Binding(
            get: { wakePurchaseStore.message != nil },
            set: { if !$0 { wakePurchaseStore.clearResult() } }
        )
    }

    @MainActor
    private func activate() async {
        let opensWakeOptions = WakeLaunchRequest.consume()
        if opensWakeOptions { navigationPath = NavigationPath() }
        await model.refresh()
        if opensWakeOptions {
            for _ in 0..<40 where model.isRefreshing {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        if opensWakeOptions, model.activeLock != nil {
            wakeTarget = model.activeLock
        }
    }
}
