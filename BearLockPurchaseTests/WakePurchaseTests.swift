import BearLockCore
import StoreKit
import StoreKitTest
import XCTest

@MainActor
final class WakePurchaseTests: XCTestCase {
    private var session: SKTestSession!
    private var store: WakePurchaseStore!
    private var deliveredTransactions: [UInt64] = []
    private var abandonCount = 0
    private var deliveryToReturn: WakePurchaseDelivery = .unlocked

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SupportProducts", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        DiagnosticsLogger.shared.clear()
        store = WakePurchaseStore()
        store.start(deliver: { [weak self] transactionID, _ in
            self?.deliveredTransactions.append(transactionID)
            return self?.deliveryToReturn
        }, abandon: { [weak self] in
            self?.abandonCount += 1
        })
    }

    override func tearDown() async throws {
        store = nil
        session.clearTransactions()
        session.resetToDefaultState()
        session = nil
        deliveredTransactions = []
        abandonCount = 0
    }

    func testWakeProductLoadsAndVerifiedPurchaseIsDeliveredBeforeFinish() async throws {
        await store.loadProduct()
        XCTAssertEqual(store.product?.id, WakePurchaseStore.productID)
        XCTAssertEqual(store.product?.type, .consumable)

        await store.purchase(using: performPurchase)

        XCTAssertEqual(deliveredTransactions.count, 1)
        XCTAssertEqual(store.lastDelivery, .unlocked)
        XCTAssertFalse(store.isPurchasing)
        let finishedEvent = try XCTUnwrap(DiagnosticsLogger.shared.snapshot().events.first { $0.name == "Purchase.wake.finished" })
        XCTAssertTrue(finishedEvent.detail?.contains("product=\(WakePurchaseStore.productID)") == true)
        XCTAssertTrue(finishedEvent.detail?.contains("delivery=unlocked") == true)
    }

    func testVerifiedTimedAllowancePurchaseIsDeliveredBeforeTransactionFinish() async throws {
        deliveryToReturn = .allowanceUnlocked
        await store.loadProduct()

        await store.purchaseDailyAllowanceUnlock(using: performPurchase)

        XCTAssertEqual(deliveredTransactions.count, 1)
        XCTAssertEqual(store.lastDelivery, .allowanceUnlocked)
        XCTAssertNil(store.message)
        let finishedEvent = try XCTUnwrap(DiagnosticsLogger.shared.snapshot().events.first { $0.name == "Purchase.wake.finished" })
        XCTAssertTrue(finishedEvent.detail?.contains("product=\(WakePurchaseStore.dailyAllowanceProductID)") == true)
        XCTAssertTrue(finishedEvent.detail?.contains("delivery=allowanceUnlocked") == true)
    }

    func testPurchaseFailureAbandonsPendingIntent() async throws {
        await store.loadProduct()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)

        await store.purchase(using: performPurchase)

        XCTAssertEqual(abandonCount, 1)
        XCTAssertTrue(deliveredTransactions.isEmpty)
        XCTAssertNil(store.lastDelivery)
        XCTAssertEqual(store.message, L10n.string("Immediate wake-up could not be purchased."))
        XCTAssertTrue(DiagnosticsLogger.shared.snapshot().events.contains { $0.name == "Purchase.wake.failed" })
    }

    func testApprovedAskToBuyCanBecomeCredit() async throws {
        store = WakePurchaseStore()
        store.start(deliver: { _, _ in .credited }, abandon: {})
        await store.loadProduct()
        session.askToBuyEnabled = true

        await store.purchase(using: performPurchase)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)

        try await eventually { self.store.lastDelivery == .credited }
        XCTAssertEqual(store.message, L10n.string("This lock already ended. Your wake-up ticket is saved for next time."))
        XCTAssertTrue(DiagnosticsLogger.shared.snapshot().events.contains { $0.name == "Purchase.wake.finished" })
    }

    private func performPurchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }

    private func eventually(_ condition: () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("StoreKit did not reach the expected state within 10 seconds", file: file, line: line)
    }
}
