import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: BearLockAppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.authorizationStatus {
                case .approved:
                    HomeView()
                case .denied, .unknown:
                    SetupView()
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
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.lastErrorMessage != nil },
            set: { if !$0 { model.lastErrorMessage = nil } }
        )
    }
}
