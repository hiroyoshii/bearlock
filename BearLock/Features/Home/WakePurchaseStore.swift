import BearLockCore
import Combine
import Foundation
import StoreKit

@MainActor
final class WakePurchaseStore: ObservableObject {
    static let productID = WakeProduct.immediateWakeID
    static let dailyAllowanceProductID = WakeProduct.timedAllowanceUnlockID

    @Published private(set) var product: Product?
    @Published private(set) var dailyAllowanceProduct: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var message: String?
    @Published private(set) var lastDelivery: WakePurchaseDelivery?

    private let diagnostics = DiagnosticsLogger.shared
    private var deliver: (@MainActor @Sendable (UInt64, String) async -> WakePurchaseDelivery?)?
    private var abandon: (@MainActor @Sendable () async -> Void)?
    private var updatesTask: Task<Void, Never>?
    private var unfinishedTask: Task<Void, Never>?

    var displayPrice: String? {
        #if DEBUG
        if usesStaticProduct || usesUITesting { return "¥500" }
        #endif
        return product?.displayPrice
    }

    var isAvailable: Bool {
        #if DEBUG
        if usesStaticProduct || usesUITesting { return true }
        #endif
        return product != nil
    }

    var dailyAllowanceDisplayPrice: String? {
        #if DEBUG
        if usesStaticProduct || usesUITesting { return "¥500" }
        #endif
        return dailyAllowanceProduct?.displayPrice
    }

    var isDailyAllowancePurchaseAvailable: Bool {
        #if DEBUG
        if usesStaticProduct || usesUITesting { return true }
        #endif
        return dailyAllowanceProduct != nil
    }

    func start(
        deliver: @escaping @MainActor @Sendable (UInt64, String) async -> WakePurchaseDelivery?,
        abandon: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.deliver = deliver
        self.abandon = abandon
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.complete(result)
            }
        }
        unfinishedTask = Task { [weak self] in
            for await result in Transaction.unfinished {
                guard !Task.isCancelled else { return }
                await self?.complete(result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        unfinishedTask?.cancel()
    }

    func loadProduct() async {
        guard !usesStaticProduct, !usesUITesting,
              (product == nil || dailyAllowanceProduct == nil), !isLoading
        else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loadedProducts = try await Product.products(for: [Self.productID, Self.dailyAllowanceProductID])
                .filter { $0.type == .consumable }
            product = loadedProducts.first { $0.id == Self.productID }
            dailyAllowanceProduct = loadedProducts.first { $0.id == Self.dailyAllowanceProductID }
            if product == nil {
                diagnostics.record(
                    "Purchase.wake.product.unavailable",
                    level: .warning,
                    detail: "product=\(Self.productID)"
                )
                message = L10n.string("Immediate wake-up is not available yet.")
            } else {
                diagnostics.record("Purchase.wake.product.loaded", detail: "product=\(Self.productID)")
            }
            if dailyAllowanceProduct == nil {
                diagnostics.record("Purchase.dailyUnlock.product.unavailable", level: .warning,
                    detail: "product=\(Self.dailyAllowanceProductID)")
            } else {
                diagnostics.record("Purchase.dailyUnlock.product.loaded", detail: "product=\(Self.dailyAllowanceProductID)")
            }
        } catch {
            diagnostics.recordError(
                "Purchase.wake.product.failed",
                error: error,
                detail: "product=\(Self.productID)"
            )
            message = L10n.string("Immediate wake-up could not be loaded.")
        }
    }

    func purchase(
        using purchase: @MainActor (Product) async throws -> Product.PurchaseResult
    ) async {
        await performPurchase(product, using: purchase)
    }

    func purchaseDailyAllowanceUnlock(
        using purchase: @MainActor (Product) async throws -> Product.PurchaseResult
    ) async {
        await performPurchase(dailyAllowanceProduct, using: purchase)
    }

    private func performPurchase(
        _ product: Product?,
        using performPurchase: @MainActor (Product) async throws -> Product.PurchaseResult
    ) async {
        guard !usesStaticProduct, !usesUITesting, !isPurchasing, let product else { return }
        guard AppStore.canMakePayments else {
            diagnostics.record(
                "Purchase.wake.notAllowed",
                level: .warning,
                detail: "product=\(product.id)"
            )
            await abandon?()
            message = L10n.string("Purchases are not allowed on this device.")
            return
        }
        diagnostics.record("Purchase.wake.started", detail: "product=\(product.id)")
        message = nil
        lastDelivery = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await performPurchase(product) {
            case let .success(verification):
                await complete(verification)
            case .userCancelled:
                diagnostics.record("Purchase.wake.cancelled", detail: "product=\(product.id)")
                await abandon?()
                message = L10n.string("The purchase was cancelled.")
            case .pending:
                diagnostics.record("Purchase.wake.pending", detail: "product=\(product.id)")
                message = product.id == Self.dailyAllowanceProductID
                    ? L10n.string("The timed unlock purchase is pending approval.")
                    : L10n.string("The purchase is pending. If this lock ends first, the purchase becomes a wake-up ticket.")
            @unknown default:
                diagnostics.record(
                    "Purchase.wake.unknownResult",
                    level: .warning,
                    detail: "product=\(product.id)"
                )
                await abandon?()
                message = L10n.string("Immediate wake-up could not be purchased.")
            }
        } catch {
            diagnostics.recordError(
                "Purchase.wake.failed",
                error: error,
                detail: "product=\(product.id)"
            )
            await abandon?()
            message = L10n.string("Immediate wake-up could not be purchased.")
        }
    }

    func clearResult() {
        lastDelivery = nil
        message = nil
    }

    private func complete(_ result: VerificationResult<Transaction>) async {
        switch result {
        case let .verified(transaction):
            guard [Self.productID, Self.dailyAllowanceProductID].contains(transaction.productID),
                  transaction.productType == .consumable else { return }
            diagnostics.record(
                "Purchase.wake.verified",
                detail: "product=\(transaction.productID) transaction=\(transaction.id) revoked=\(transaction.revocationDate != nil)"
            )
            guard transaction.revocationDate == nil,
                  let delivery = await deliver?(transaction.id, transaction.productID)
            else {
                diagnostics.record(
                    "Purchase.wake.delivery.failed",
                    level: .error,
                    detail: "product=\(transaction.productID) transaction=\(transaction.id)"
                )
                message = L10n.string("The purchase could not be verified.")
                return
            }
            await transaction.finish()
            diagnostics.record(
                "Purchase.wake.finished",
                detail: "product=\(transaction.productID) transaction=\(transaction.id) delivery=\(delivery)"
            )
            lastDelivery = delivery
            switch delivery {
            case .unlocked, .allowanceUnlocked, .alreadyHandled:
                message = nil
            case .credited:
                message = L10n.string("This lock already ended. Your wake-up ticket is saved for next time.")
            }
        case let .unverified(transaction, error):
            diagnostics.recordError(
                "Purchase.wake.unverified",
                error: error,
                detail: "product=\(transaction.productID) transaction=\(transaction.id)"
            )
            if [Self.productID, Self.dailyAllowanceProductID].contains(transaction.productID) {
                await abandon?()
            }
            message = L10n.string("The purchase could not be verified.")
        }
    }

    private var usesStaticProduct: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--screenshot")
        #else
        false
        #endif
    }

    private var usesUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
}
