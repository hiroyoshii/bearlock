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

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SupportProducts", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        let unfinished = try await synchronizedUnfinishedTransactionIDs()
        XCTAssertTrue(unfinished.isEmpty)
        DiagnosticsLogger.shared.clear()
        store = WakePurchaseStore()
        store.start(deliver: { [weak self] transactionID in
            self?.deliveredTransactions.append(transactionID)
            return .unlocked
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
        try await awaitStoreKitState { try await synchronizedUnfinishedTransactionIDs().isEmpty }
    }

    func testCancelledPurchaseAbandonsPendingIntent() async throws {
        await store.loadProduct()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)

        await store.purchase(using: performPurchase)

        XCTAssertEqual(abandonCount, 1)
        XCTAssertTrue(deliveredTransactions.isEmpty)
        XCTAssertNil(store.lastDelivery)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertFalse(session.allTransactions().contains { $0.state == .purchased })
        XCTAssertEqual(store.message, L10n.string("The purchase could not be completed."))
        let events = DiagnosticsLogger.shared.snapshot().events
        let failure = try XCTUnwrap(events.first { $0.name == "Purchase.wake.failed" })
        let detail = try XCTUnwrap(failure.detail)
        XCTAssertTrue(detail.contains("product=\(WakePurchaseStore.productID)"))
        XCTAssertFalse(events.contains { $0.name == "Purchase.wake.verified" || $0.name == "Purchase.wake.finished" })
    }

    func testApprovedAskToBuyCanBecomeCredit() async throws {
        store = WakePurchaseStore()
        store.start(deliver: { _ in .credited }, abandon: {})
        await store.loadProduct()
        session.askToBuyEnabled = true

        await store.purchase(using: performPurchase)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)

        try await awaitStoreKitState { self.store.lastDelivery == .credited }
        XCTAssertEqual(store.message, L10n.string("This lock already ended. Your wake-up ticket is saved for next time."))
        try await awaitStoreKitState { try await synchronizedUnfinishedTransactionIDs().isEmpty }
    }

    private func performPurchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }


}
