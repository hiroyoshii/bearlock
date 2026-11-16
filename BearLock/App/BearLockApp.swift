import SwiftUI
import UIKit

@main
struct BearLockApp: App {
    init() {
        let segments = UISegmentedControl.appearance()
        segments.selectedSegmentTintColor = UIColor(AppTheme.navy)
        segments.backgroundColor = UIColor(AppTheme.ice)
        segments.setTitleTextAttributes([.foregroundColor: UIColor(AppTheme.navy)], for: .normal)
        segments.setTitleTextAttributes([.foregroundColor: UIColor(AppTheme.snow)], for: .selected)
    }

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
            .tint(AppTheme.navy)
        }
    }

    private var rootContent: some View {
        RootView()
            .environmentObject(model)
            .task {
                wakePurchaseStore.start(
                    deliver: { transactionID, productID in
                        await model.deliverWakePurchase(transactionID: transactionID, productID: productID)
                    },
                    abandon: {
                        await model.abandonWakePurchase()
                    }
                )
                await wakePurchaseStore.loadProduct()
            }
    }
}
