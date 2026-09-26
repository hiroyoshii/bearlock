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
            if product == nil { message = L10n.string("Immediate wake-up is not available yet.") }
        } catch {
            message = L10n.string("Immediate wake-up could not be loaded.")
        }
    }

    func purchase() async {
        guard !usesStaticProduct, !usesUITesting, !isPurchasing, let product else { return }
        message = nil
        lastDelivery = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case let .success(verification):
                await complete(verification)
            case .userCancelled:
                await abandon?()
            case .pending:
                message = L10n.string("The purchase is pending. If this lock ends first, the purchase becomes a wake-up ticket.")
            @unknown default:
                await abandon?()
                message = L10n.string("Immediate wake-up could not be purchased.")
            }
        } catch {
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
            guard transaction.productID == Self.productID, transaction.productType == .consumable else { return }
            guard transaction.revocationDate == nil, let delivery = await deliver?(transaction.id) else {
                message = L10n.string("The purchase could not be verified.")
                return
            }
            await transaction.finish()
            lastDelivery = delivery
            switch delivery {
            case .unlocked, .alreadyHandled:
                message = nil
            case .credited:
                message = L10n.string("This lock already ended. Your wake-up ticket is saved for next time.")
            }
        case let .unverified(transaction, _):
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
