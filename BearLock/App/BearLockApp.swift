import SwiftUI

@main
struct BearLockApp: App {
    @StateObject private var model = BearLockAppModel.live()

    @StateObject private var supportStore = SupportStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let screenshotScreen = ScreenshotScreen.current() {
                    ScreenshotHostView(screen: screenshotScreen)
                } else {
                    RootView()
                        .environmentObject(model)
                        .task {
                            await model.refresh()
                        }
                }
            }
            .environmentObject(supportStore)
        }
    }
}
