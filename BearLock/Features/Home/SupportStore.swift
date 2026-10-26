import Combine
import Foundation
import StoreKit

enum SupportProduct: String, CaseIterable, Identifiable {
    case coffee
    case lunch
    case dinner

    var id: String { productID }

    var productID: String {
        switch self {
        case .coffee:
            return "com.hiyozoo.bearlock.support.coffee"
        case .lunch:
            return "com.hiyozoo.bearlock.support.lunch"
        case .dinner:
            return "com.hiyozoo.bearlock.support.dinner"
        }
    }

    var titleKey: String {
        switch self {
        case .coffee:
            return "Coffee"
        case .lunch:
            return "Lunch"
        case .dinner:
            return "Dinner"
        }
    }

    #if DEBUG
    var fallbackPrice: String {
        switch self {
        case .coffee:
            return "¥500"
        case .lunch:
            return "¥1,000"
        case .dinner:
            return "¥2,000"
        }
    }
    #endif
}

@MainActor
final class SupportStore: ObservableObject {
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var message: String?
    private let diagnostics = DiagnosticsLogger.shared
    private var updatesTask: Task<Void, Never>?
    private var unfinishedTask: Task<Void, Never>?

    init() {
        guard !usesStaticSupportProducts else { return }
        // Keep listening even after the support screen has closed (e.g. Ask to Buy).
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

    private func complete(_ result: VerificationResult<Transaction>) async {
        switch result {
        case let .verified(transaction):
            guard SupportProduct.allCases.contains(where: { $0.productID == transaction.productID }),
                  transaction.productType == .consumable else { return }
            diagnostics.record(
                "Purchase.support.verified",
                detail: "product=\(transaction.productID) transaction=\(transaction.id) revoked=\(transaction.revocationDate != nil)"
            )
            // Support purchases grant no entitlement or lock-related privileges.
            await transaction.finish()
            diagnostics.record(
                "Purchase.support.finished",
                detail: "product=\(transaction.productID) transaction=\(transaction.id)"
            )
            if transaction.revocationDate == nil {
                message = L10n.string("Thank you. This helps Bear Lock keep growing quietly.")
            }
        case let .unverified(transaction, error):
            diagnostics.recordError(
                "Purchase.support.unverified",
                error: error,
                detail: "product=\(transaction.productID) transaction=\(transaction.id)"
            )
            message = L10n.string("The purchase could not be verified.")
        }
    }

    func loadProducts() async {
        guard !isLoading, purchasingProductID == nil else { return }
        guard !usesStaticSupportProducts else {
            #if DEBUG
            if !ProcessInfo.processInfo.arguments.contains("--screenshot") {
                message = L10n.string("Support items are not available yet.")
            }
            #endif
            return
        }
        message = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: SupportProduct.allCases.map(\.productID))
            products = Dictionary(uniqueKeysWithValues: loadedProducts.filter { $0.type == .consumable }.map { ($0.id, $0) })
            diagnostics.record(
                "Purchase.support.products.loaded",
                detail: "requested=\(SupportProduct.allCases.count) loaded=\(products.count)"
            )
            if products.count < SupportProduct.allCases.count {
                message = L10n.string("Support items are not available yet.")
            }
        } catch {
            diagnostics.recordError("Purchase.support.products.failed", error: error)
            message = L10n.string("Support items could not be loaded.")
        }
    }

    func product(for supportProduct: SupportProduct) -> Product? {
        products[supportProduct.productID]
    }

    func purchase(
        _ supportProduct: SupportProduct,
        using purchase: @MainActor (Product) async throws -> Product.PurchaseResult
    ) async {
        guard purchasingProductID == nil, !isLoading else { return }
        guard AppStore.canMakePayments else {
            diagnostics.record(
                "Purchase.support.notAllowed",
                level: .warning,
                detail: "product=\(supportProduct.productID)"
            )
            message = L10n.string("Purchases are not allowed on this device.")
            return
        }
        guard let product = product(for: supportProduct) else {
            diagnostics.record(
                "Purchase.support.unavailable",
                level: .warning,
                detail: "product=\(supportProduct.productID)"
            )
            message = L10n.string("Support items are not available yet.")
            return
        }

        diagnostics.record("Purchase.support.started", detail: "product=\(product.id)")
        message = nil
        purchasingProductID = supportProduct.productID
        defer { purchasingProductID = nil }

        do {
            let result = try await purchase(product)

            switch result {
            case let .success(verification):
                await complete(verification)
            case .userCancelled:
                diagnostics.record("Purchase.support.failed", detail: "product=\(product.id) result=userCancelled")
                message = L10n.string("The purchase could not be completed.")
            case .pending:
                diagnostics.record("Purchase.support.pending", detail: "product=\(product.id)")
                message = L10n.string("The purchase is pending.")
            @unknown default:
                diagnostics.record(
                    "Purchase.support.failed",
                    level: .warning,
                    detail: "product=\(product.id) result=unknown"
                )
                message = L10n.string("The purchase could not be completed.")
            }
        } catch {
            diagnostics.recordError(
                "Purchase.support.failed",
                error: error,
                detail: "product=\(product.id)"
            )
            message = L10n.string("The purchase could not be completed.")
        }
    }

    private var usesStaticSupportProducts: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--screenshot")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
}
