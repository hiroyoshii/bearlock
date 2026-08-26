import SwiftUI

@main
struct BearLockApp: App {
    @StateObject private var model = BearLockAppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    await model.refresh()
                }
        }
    }
}
