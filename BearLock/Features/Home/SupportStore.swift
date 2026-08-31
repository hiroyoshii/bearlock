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
}

@MainActor
final class SupportStore: ObservableObject {
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var message: String?

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: SupportProduct.allCases.map(\.productID))
            products = Dictionary(uniqueKeysWithValues: loadedProducts.map { ($0.id, $0) })
            if loadedProducts.isEmpty {
                message = L10n.string("Support items are not available yet.")
            }
        } catch {
            message = L10n.string("Support items could not be loaded.")
        }
    }

    func product(for supportProduct: SupportProduct) -> Product? {
        products[supportProduct.productID]
    }

    func purchase(_ supportProduct: SupportProduct) async {
        guard let product = product(for: supportProduct) else {
            message = L10n.string("Support items are not available yet.")
            return
        }

        purchasingProductID = supportProduct.productID
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case let .success(.verified(transaction)):
                await transaction.finish()
                message = L10n.string("Thank you. This helps Bear Lock keep growing quietly.")
            case .success(.unverified):
                message = L10n.string("The purchase could not be verified.")
            case .userCancelled:
                message = nil
            case .pending:
                message = L10n.string("The purchase is pending.")
            @unknown default:
                message = L10n.string("The purchase could not be completed.")
            }
        } catch {
            message = L10n.string("The purchase could not be completed.")
        }
    }
}
