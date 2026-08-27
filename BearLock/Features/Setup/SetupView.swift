import FamilyControls
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                BearDenArt()
                    .frame(maxWidth: 230)

                BrandLockup(
                    subtitle: "Disappear for a while.",
                    compact: false
                )

                Text("決めた時間まで、選んだアプリを静かに眠らせます。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.navy.opacity(0.72))
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await model.requestAuthorization()
                    }
                } label: {
                    Label("Screen Timeアクセスを許可", systemImage: "hourglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)

                Button {
                    isPickerPresented = true
                } label: {
                    Label("ブロック対象アプリを選ぶ", systemImage: "app.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.steel)
            }
            .controlSize(.large)

            Text("選択内容は端末内とApp Group領域に保存します。MVPではアカウントやクラウド同期は使いません。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.navy.opacity(0.58))

            Spacer()
        }
        .padding(24)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: isPickerPresented) { _, presented in
            guard !presented else { return }
            Task {
                await model.saveSelection(selection)
            }
        }
    }
}
