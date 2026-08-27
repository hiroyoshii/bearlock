import SwiftUI

@main
struct BearLockApp: App {
    @StateObject private var model = BearLockAppModel.live()

    var body: some Scene {
        WindowGroup {
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
    }
}
