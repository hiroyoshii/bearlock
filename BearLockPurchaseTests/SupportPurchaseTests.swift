import XCTest
import StoreKit
import StoreKitTest

@MainActor
final class SupportPurchaseTests: XCTestCase {
    private var session: SKTestSession!
    private var store: SupportStore!
    private let thanks = L10n.string("Thank you. This helps Bear Lock keep growing quietly.")

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SupportProducts", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        store = SupportStore()
    }

    override func tearDown() async throws {
        store = nil
        session.clearTransactions()
        session.resetToDefaultState()
        session = nil
    }

    func testAllProductsLoadAndCanBePurchasedRepeatedly() async throws {
        await store.loadProducts()
        XCTAssertEqual(Set(store.products.keys), Set(SupportProduct.allCases.map(\.productID)))
        XCTAssertFalse(store.isLoading)
        for item in SupportProduct.allCases {
            let product = try XCTUnwrap(store.product(for: item))
            XCTAssertEqual(product.type, .consumable)
            XCTAssertFalse(product.displayPrice.isEmpty)
            for _ in 0..<2 {
                await store.purchase(item)
                XCTAssertEqual(store.message, thanks)
                XCTAssertNil(store.purchasingProductID)
            }
        }
        XCTAssertEqual(session.allTransactions().count, 6)
        try await eventually { await self.unfinishedIDs().isEmpty }
    }

    func testPurchaseWithoutLoadedProductDoesNotCreateTransaction() async {
        await store.purchase(.coffee)
        XCTAssertEqual(store.message, L10n.string("Support items are not available yet."))
        XCTAssertTrue(session.allTransactions().isEmpty)
        XCTAssertNil(store.purchasingProductID)
    }

    func testPurchaseFailureCanBeRetried() async throws {
        await store.loadProducts()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await store.purchase(.coffee)
        XCTAssertEqual(store.message, L10n.string("The purchase could not be completed."))
        XCTAssertNil(store.purchasingProductID)
        // Reset the test server's forced-failure state, retaining the same app service.
        session.resetToDefaultState()
        session.disableDialogs = true
        let remainingError = await session.simulatedError(forAPI: .purchase)
        XCTAssertNil(remainingError)
        await store.purchase(.coffee)
        XCTAssertEqual(store.message, thanks)
        try await eventually { await self.unfinishedIDs().isEmpty }
    }

    func testCancelledPurchaseDoesNotShowSuccess() async throws {
        await store.loadProducts()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await store.purchase(.coffee)
        XCTAssertNil(store.message)
        XCTAssertNil(store.purchasingProductID)
        // StoreKit Testing records cancelled attempts too; they must not be successful payments.
        XCTAssertFalse(session.allTransactions().contains { $0.state == .purchased })
        let remaining = await unfinishedIDs()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testPendingPurchaseFinishesWhenApproved() async throws {
        await store.loadProducts()
        session.askToBuyEnabled = true
        await store.purchase(.coffee)
        XCTAssertEqual(store.message, L10n.string("The purchase is pending."))
        XCTAssertNil(store.purchasingProductID)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await eventually { self.store.message == self.thanks }
        try await eventually { await self.unfinishedIDs().isEmpty }
    }

    func testStartupRecoversUnfinishedSupportPurchase() async throws {
        // No service exists when the transaction is created; the next instance must recover it.
        store = nil
        let transaction = try await session.buyProduct(identifier: SupportProduct.lunch.productID, options: [])
        try await eventually { await self.unfinishedIDs().contains(transaction.id) }
        store = SupportStore()
        try await eventually { self.store.message == self.thanks }
        try await eventually { await self.unfinishedIDs().isEmpty }
    }

    func testUnrelatedPurchaseIsNotFinishedBySupportStore() async throws {
        store = nil
        let transaction = try await session.buyProduct(identifier: "com.hiyozoo.bearlock.test.unrelated", options: [])
        store = SupportStore()
        await store.loadProducts()
        // A support purchase confirms that the service has processed StoreKit work.
        await store.purchase(.coffee)
        XCTAssertEqual(store.message, thanks)
        let remaining = await unfinishedIDs()
        XCTAssertTrue(remaining.contains(transaction.id))
        await transaction.finish()
    }

    private func unfinishedIDs() async -> Set<UInt64> {
        var result = Set<UInt64>()
        for await verification in Transaction.unfinished {
            if case let .verified(transaction) = verification { result.insert(transaction.id) }
        }
        return result
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
