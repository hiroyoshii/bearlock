import BearLockCore
import Combine
import Foundation
import StoreKit

@MainActor
final class WakePurchaseStore: ObservableObject {
    static let productID = "com.hiyozoo.bearlock.wake.now"

    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var message: String?
    @Published private(set) var lastDelivery: WakePurchaseDelivery?

    private let diagnostics = DiagnosticsLogger.shared
    private var deliver: (@MainActor @Sendable (UInt64) async -> WakePurchaseDelivery?)?
    private var abandon: (@MainActor @Sendable () async -> Void)?
    private var updatesTask: Task<Void, Never>?
    private var unfinishedTask: Task<Void, Never>?

    var displayPrice: String? {
        #if DEBUG
        if usesStaticProduct { return "¥500" }
        #endif
        return product?.displayPrice
    }

    var isAvailable: Bool {
        usesStaticProduct || product != nil
    }

    func start(
        deliver: @escaping @MainActor @Sendable (UInt64) async -> WakePurchaseDelivery?,
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
        guard !usesStaticProduct, !usesUITesting, product == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.type == .consumable }
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
            switch try await purchase(product) {
            case let .success(verification):
                await complete(verification)
            case .userCancelled:
                diagnostics.record("Purchase.wake.failed", detail: "product=\(product.id) result=userCancelled")
                await abandon?()
                message = L10n.string("The purchase could not be completed.")
            case .pending:
                diagnostics.record("Purchase.wake.pending", detail: "product=\(product.id)")
                message = L10n.string("The purchase is pending. If this lock ends first, the purchase becomes a wake-up ticket.")
            @unknown default:
                diagnostics.record(
                    "Purchase.wake.failed",
                    level: .warning,
                    detail: "product=\(product.id) result=unknown"
                )
                await abandon?()
                message = L10n.string("The purchase could not be completed.")
            }
        } catch {
            diagnostics.recordError(
                "Purchase.wake.failed",
                error: error,
                detail: "product=\(product.id)"
            )
            await abandon?()
            message = L10n.string("The purchase could not be completed.")
        }
    }

    func clearResult() {
        lastDelivery = nil
        message = nil
    }

    private func complete(_ result: VerificationResult<Transaction>) async {
        switch result {
        case let .verified(transaction):
            guard transaction.productID == Self.productID, transaction.productType == .consumable else { return }
            diagnostics.record(
                "Purchase.wake.verified",
                detail: "product=\(transaction.productID) transaction=\(transaction.id) revoked=\(transaction.revocationDate != nil)"
            )
            guard transaction.revocationDate == nil, let delivery = await deliver?(transaction.id) else {
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
            case .unlocked, .alreadyHandled:
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
            if transaction.productID == Self.productID {
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
