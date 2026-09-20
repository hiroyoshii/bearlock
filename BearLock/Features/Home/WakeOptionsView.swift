import BearLockCore
import SwiftUI
import UIKit

struct WakeOptionsView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @EnvironmentObject private var purchaseStore: WakePurchaseStore
    let activeLock: ActiveLock

    @State private var confirmsFreeWake = false
    @State private var confirmsPurchase = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                Text("Do you really need to wake the bear?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)

                if let request = model.freeWakeRequest(for: activeLock) {
                    delayedWake(request, now: context.date)
                } else {
                    wakeChoices(now: context.date)
                }

                if let message = purchaseStore.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.navy.opacity(0.72))
                        .accessibilityIdentifier("wake-purchase-message")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.navy.opacity(0.12), lineWidth: 1)
            )
            .confirmationDialog(
                "Wake the bear in 30 minutes?",
                isPresented: $confirmsFreeWake,
                titleVisibility: .visible
            ) {
                Button("Start 30-minute wake-up") {
                    Task { _ = await model.scheduleFreeWake(for: activeLock) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The lock stays active for another 30 minutes. You can cancel the request before then.")
            }
            .confirmationDialog(
                "Wake the bear now?",
                isPresented: $confirmsPurchase,
                titleVisibility: .visible
            ) {
                Button(purchaseButtonTitle) {
                    Task {
                        guard await model.beginWakePurchase(for: activeLock) else { return }
                        await purchaseStore.purchase()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This purchase ends only the current lock. Future repeating locks stay scheduled.")
            }
        }
    }

    private func delayedWake(_ request: WakeRequest, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Waking the bear", systemImage: "alarm")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
            Text(delayedRemainingText(until: request.wakesAt, now: now))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(AppTheme.navy)
                .accessibilityLabel(
                    L10n.format("Wakes at %@", request.wakesAt.formatted(date: .omitted, time: .shortened))
                )
            immediateWakeControl(now: now)
            Button("Cancel wake-up", role: .cancel) {
                Task { await model.cancelFreeWake(for: activeLock) }
            }
            .disabled(model.isHandlingWake)
            .accessibilityIdentifier("cancel-free-wake")
        }
    }

    @ViewBuilder
    private func wakeChoices(now: Date) -> some View {
        let remaining = activeLock.remainingTime(at: now)

        immediateWakeControl(now: now)

        if remaining > WakePolicy.freeDelay {
            Button("Wake in 30 minutes for free") {
                confirmsFreeWake = true
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.navy)
            .disabled(model.isHandlingWake || purchaseStore.isPurchasing)
            .accessibilityIdentifier("schedule-free-wake")
        } else {
            Text("Less than 30 minutes remain. The bear will wake at the scheduled time.")
                .font(.footnote)
                .foregroundStyle(AppTheme.navy.opacity(0.62))
        }
    }

    @ViewBuilder
    private func immediateWakeControl(now: Date) -> some View {
        if model.hasWakeCredit {
            Button("Use wake-up ticket") {
                Task { _ = await model.useWakeCredit(for: activeLock) }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.navy)
            .disabled(model.isHandlingWake)
            .accessibilityIdentifier("use-wake-credit")
        } else if model.lockState.wakeState.pendingPurchase != nil {
            Label("Purchase approval is pending", systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(AppTheme.navy.opacity(0.72))
        } else if activeLock.remainingTime(at: now) > WakePolicy.minimumPaidRemainingTime {
            Button(purchaseButtonTitle) {
                confirmsPurchase = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.navy)
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

    private func delayedRemainingText(until date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct WakeOptionsSheet: View {
    @EnvironmentObject private var model: BearLockAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let activeLock = model.activeLock {
                    VStack(spacing: 20) {
                        ActiveLockView(activeLock: activeLock)
                        WakeOptionsView(activeLock: activeLock)
                    }
                    .padding(20)
                } else {
                    ContentUnavailableView(
                        "This lock has already ended.",
                        systemImage: "sun.max",
                        description: Text("The selected apps are available again.")
                    )
                    .padding(20)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Wake the bear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
