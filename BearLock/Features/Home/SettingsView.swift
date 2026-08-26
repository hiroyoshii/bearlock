import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("データの扱い") {
                Text("MVPでは選択アプリとロック予定を端末内のApp Group領域に保存します。アカウント、クラウド同期、利用統計は扱いません。")
                    .font(.body)
            }
        }
        .navigationTitle("Settings")
    }
}
