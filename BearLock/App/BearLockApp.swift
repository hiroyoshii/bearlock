import SwiftUI

@main
struct BearLockApp: App {
    @StateObject private var model = BearLockAppModel.live()

    @StateObject private var supportStore = SupportStore()
    @StateObject private var wakePurchaseStore = WakePurchaseStore()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let screenshotScreen = ScreenshotScreen.current() {
                    ScreenshotHostView(screen: screenshotScreen)
                } else {
                    rootContent
                }
                #else
                rootContent
                #endif
            }
            .environmentObject(supportStore)
            .environmentObject(wakePurchaseStore)
        }
    }

    private var rootContent: some View {
        RootView()
            .environmentObject(model)
            .task {
                wakePurchaseStore.start(
                    deliver: { transactionID in
                        await model.deliverWakePurchase(transactionID: transactionID)
                    },
                    abandon: {
                        await model.abandonWakePurchase()
                    }
                )
                await wakePurchaseStore.loadProduct()
            }
    }
}
