import BearLockCore
import StoreKit
import SwiftUI
import UIKit

struct WakeOptionsDialog: ViewModifier {
    @Environment(\.purchase) private var purchase
    @EnvironmentObject private var model: BearLockAppModel
    @EnvironmentObject private var purchaseStore: WakePurchaseStore
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Wake the bear",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            if let activeLock = model.activeLock {
                wakeActions(for: activeLock)
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text(dialogMessage)
        }
    }

    @ViewBuilder
    private func wakeActions(for activeLock: ActiveLock) -> some View {
        if model.freeWakeRequest(for: activeLock) != nil {
            immediateWakeAction(for: activeLock)

            Button("Cancel wake-up", role: .destructive) {
                Task { await model.cancelFreeWake(for: activeLock) }
            }
            .accessibilityIdentifier("cancel-free-wake")
        } else {
            immediateWakeAction(for: activeLock)

            if activeLock.remainingTime(at: Date()) > WakePolicy.freeDelay {
                Button("Wake in 30 minutes for free") {
                    Task { _ = await model.scheduleFreeWake(for: activeLock) }
                }
                .disabled(model.isHandlingWake || purchaseStore.isPurchasing)
                .accessibilityIdentifier("schedule-free-wake")
            }
        }
    }

    @ViewBuilder
    private func immediateWakeAction(for activeLock: ActiveLock) -> some View {
        if model.hasWakeCredit {
            Button("Use wake-up ticket") {
                Task { _ = await model.useWakeCredit(for: activeLock) }
            }
            .disabled(model.isHandlingWake)
            .accessibilityIdentifier("use-wake-credit")
        } else if model.lockState.wakeState.pendingPurchase == nil,
                  activeLock.remainingTime(at: Date()) > WakePolicy.minimumPaidRemainingTime {
            Button(purchaseButtonTitle) {
                Task {
                    guard await model.beginWakePurchase(for: activeLock) else { return }
                    await purchaseStore.purchase { product in
                        try await purchase(product)
                    }
                }
            }
            .disabled(!purchaseStore.isAvailable || purchaseStore.isPurchasing || model.isHandlingWake)
            .accessibilityIdentifier("purchase-immediate-wake")
        }
    }

    private var purchaseButtonTitle: String {
        guard let price = purchaseStore.displayPrice else {
            return L10n.string("Wake now")
        }
        return L10n.format("Wake now for %@", price)
    }

    private var dialogMessage: String {
        guard let activeLock = model.activeLock else {
            return L10n.string("This lock has already ended.")
        }
        if let request = model.freeWakeRequest(for: activeLock) {
            return L10n.format("Wakes at %@", request.wakesAt.formatted(date: .omitted, time: .shortened))
        }
        if model.lockState.wakeState.pendingPurchase != nil {
            return L10n.string("Purchase approval is pending")
        }
        return L10n.string("A wake-up ends only the current lock. Future repeating locks stay scheduled.")
    }
}

extension View {
    func wakeOptionsDialog(isPresented: Binding<Bool>) -> some View {
        modifier(WakeOptionsDialog(isPresented: isPresented))
    }
}

struct WakeResultView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            wakeVisual
                .frame(maxWidth: 300)
                .accessibilityHidden(true)
            Text("Woken up with honey…")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.navy)
            Text("The current lock has ended.")
                .foregroundStyle(AppTheme.navy.opacity(0.72))
            Spacer()
            Button("Get up") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.navy)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("dismiss-wake-result")
        }
        .padding(24)
        .background(AppTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var wakeVisual: some View {
        if UIImage(named: "BearVisualForcedAwake") != nil {
            Image("BearVisualForcedAwake")
                .resizable()
                .scaledToFit()
        } else {
            BearStateVisual(state: .ready)
        }
    }
}
