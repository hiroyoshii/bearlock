import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenIntroduction") private var hasSeenIntroduction = false
    @EnvironmentObject private var model: BearLockAppModel
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await model.refresh()
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )
    }
}
