import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenIntroduction") private var hasSeenIntroduction = false
    @EnvironmentObject private var model: BearLockAppModel
    @EnvironmentObject private var wakePurchaseStore: WakePurchaseStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigationID = UUID()
    @State private var wakeSheet: WakeSheet?

    var body: some View {
        NavigationStack {
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
                        HomeView()
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
        .id(navigationID)
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
            if completionID != nil { wakeSheet = .result }
        }
        .sheet(item: $wakeSheet, onDismiss: wakePurchaseStore.clearResult) { sheet in
            switch sheet {
            case .options:
                WakeOptionsSheet()
            case .result:
                WakeResultView()
                    .presentationDetents([.large])
                    .interactiveDismissDisabled()
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )
    }

    @MainActor
    private func activate() async {
        let opensWakeOptions = WakeLaunchRequest.consume()
        if opensWakeOptions { navigationID = UUID() }
        await model.refresh()
        if opensWakeOptions {
            for _ in 0..<40 where model.isRefreshing {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        if opensWakeOptions, model.activeLock != nil {
            wakeSheet = .options
        }
    }
}

private enum WakeSheet: String, Identifiable {
    case options, result
    var id: String { rawValue }
}
