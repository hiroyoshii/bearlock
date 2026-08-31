import StoreKit
import SwiftUI

struct SupportView: View {
    @StateObject private var store = SupportStore()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image("BrandAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Support Bear Lock")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.navy)
                            Text("Optional support")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.steel)
                        }
                    }

                    Text("Bear Lock is free. No ads, accounts, or subscriptions.")
                        .font(.body)
                        .foregroundStyle(AppTheme.navy)

                    Text("If you like it, you can support development. Bear Lock works the same either way, and support never changes how locks behave.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.steel)
                }
                .padding(.vertical, 8)
            }

            Section("Choose support") {
                ForEach(SupportProduct.allCases) { supportProduct in
                    Button {
                        Task {
                            await store.purchase(supportProduct)
                        }
                    } label: {
                        SupportProductRow(
                            supportProduct: supportProduct,
                            product: store.product(for: supportProduct),
                            isPurchasing: store.purchasingProductID == supportProduct.productID
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoading || store.product(for: supportProduct) == nil || store.purchasingProductID != nil)
                }
            }

            if let message = store.message {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.steel)
                }
            }
        }
        .navigationTitle("Support Bear Lock")
        .task {
            await store.loadProducts()
        }
        .refreshable {
            await store.loadProducts()
        }
    }
}

private struct SupportProductRow: View {
    let supportProduct: SupportProduct
    let product: Product?
    let isPurchasing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
                .frame(width: 32, height: 32)
                .background(AppTheme.ice, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(supportProduct.titleKey))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.steel)
            }

            Spacer(minLength: 12)

            if isPurchasing {
                ProgressView()
            } else {
                Text(product?.displayPrice ?? supportProduct.fallbackPrice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(product == nil ? AppTheme.steel : AppTheme.navy)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: LocalizedStringKey {
        product == nil ? "Available after App Store setup" : "One-time optional support"
    }

    private var iconName: String {
        switch supportProduct {
        case .coffee:
            return "cup.and.saucer"
        case .lunch:
            return "fork.knife"
        case .dinner:
            return "moon.stars"
        }
    }
}
