import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BearStateVisual(state: .ready, compact: true)
                        .frame(height: 108)
                    BrandLockup(
                        subtitle: "A private space that protects your time and energy.",
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(AppTheme.background)
            }

            Section("データの扱い") {
                Text("MVPでは選択アプリとロック予定を端末内のApp Group領域に保存します。アカウント、クラウド同期、利用統計は扱いません。")
                    .font(.body)
            }
        }
        .navigationTitle("Settings")
    }
}
