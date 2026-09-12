import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenIntroduction") private var hasSeenIntroduction = false
    @EnvironmentObject private var model: BearLockAppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if model.hasLoadedInitialState {
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
