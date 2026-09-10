import SwiftUI

// Isolated test host: the real app's launch-time listener must not consume test transactions.
@main
struct PurchaseTestHost: App {
    var body: some Scene {
        WindowGroup { Text("StoreKit test host") }
    }
}
