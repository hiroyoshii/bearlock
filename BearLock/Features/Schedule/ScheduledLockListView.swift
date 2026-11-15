import BearLockCore
import StoreKit
import SwiftUI

struct ScheduledLockListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var pendingDeletion: LockRule?
    @State private var showsDeleteConfirmation = false
    @State private var editingSheet: ScheduledLockEditSheet?
    var onWake: (ActiveLock) -> Void = { _ in }

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            Text("Configured Locks")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            if let active = model.activeLock, active.isActive(at: now) {
                ActiveLockView(activeLock: active, onWake: { onWake(active) })
            }

            if model.lockState.dailyAllowance.isConfigured {
                DailyAllowanceLockRow(now: now)
            }

            if scheduledRules(at: now).isEmpty {
                if model.activeLock == nil && !model.lockState.dailyAllowance.isConfigured {
                    Text("No scheduled locks.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.navy.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                ForEach(scheduledRules(at: now)) { rule in
                    ScheduledLockRow(
                        rule: rule,
                        canEdit: canEdit(rule, at: now),
                        now: now,
                        onEdit: {
                            if rule.kind == .recurring {
                                editingSheet = .recurring(rule)
                            } else {
                                editingSheet = .oneShot(rule)
                            }
                        },
                        onDelete: {
                            pendingDeletion = rule
                            showsDeleteConfirmation = true
                        },
                        onCancelDeletion: {
                            Task { await model.cancelScheduledDeletion(rule) }
                        }
                    )
                }
            }
        }
        .confirmationDialog("Delete this schedule?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button(role: .destructive) {
                guard let rule = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await model.deleteScheduledRule(rule) }
            } label: {
                Text(LocalizedStringKey(pendingDeletionActiveLock == nil ? "Delete" : "Delete After This Lock"))
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let active = pendingDeletionActiveLock {
                Text(L10n.format("This lock will continue until %@. The schedule and future repeating locks will then be deleted.",
                    active.endsAt.formatted(date: .abbreviated, time: .shortened)))
            } else if let interval = pendingDeletion?.displayInterval(at: Date()) {
                Text("\(interval.start.formatted()) → \(interval.end.formatted())")
            }
        }
        .sheet(item: $editingSheet) { sheet in
            switch sheet {
            case let .oneShot(rule):
                ScheduledLockEditorView(
                    rule: rule,
                    isSaving: model.isUpdatingLock,
                    onCancel: {
                        editingSheet = nil
                    },
                    onSave: { startsAt, duration in
                        Task {
                            let didUpdate = await model.updateScheduledRule(rule, startsAt: startsAt, duration: duration)
                            if didUpdate.isSaved {
                                editingSheet = nil
                            }
                        }
                    }
                )
            case let .recurring(rule):
                RecurringRuleEditorView(
                    rule: rule,
                    isSaving: model.isUpdatingLock,
                    onCancel: {
                        editingSheet = nil
                    },
                    onSave: { recurrence, enabled in
                        Task {
                            let didUpdate = await model.updateRecurringRule(rule, recurrence: recurrence, enabled: enabled)
                            if didUpdate.isSaved {
                                editingSheet = nil
                            }
                        }
                    }
                )
            }
        }
    }

    private func scheduledRules(at date: Date) -> [LockRule] {
        model.lockState.rules
            .filter { !$0.isDeleted(at: date) && $0.kind != .immediate && (!$0.isOneShot || $0.single!.endsAt > date) }
            .sorted { ($0.displayInterval(at: date)?.start ?? .distantFuture) < ($1.displayInterval(at: date)?.start ?? .distantFuture) }
    }

    private func canEdit(_ rule: LockRule, at date: Date) -> Bool {
        (try? model.lockState.validateEditable(rule, at: date)) != nil &&
            (rule.kind == .recurring || rule.single!.startsAt > date)
    }

    private var pendingDeletionActiveLock: ActiveLock? {
        guard let rule = pendingDeletion, rule.kind == .recurring else { return nil }
        return model.lockState.activeLocks(at: Date()).first { $0.id == rule.id }
    }
}

private struct DailyAllowanceLockRow: View {
    @EnvironmentObject private var model: BearLockAppModel
    @EnvironmentObject private var wakePurchaseStore: WakePurchaseStore
    @Environment(\.purchase) private var purchase
    @State private var isEditing = false
    @State private var showsPaidUnlockSheet = false
    let now: Date

    var body: some View {
        let state = model.lockState.dailyAllowanceAccessState(at: now)
        let policy = model.lockState.dailyAllowance.policy(at: now)
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                DailyAllowanceEditorView(
                    policy: model.lockState.dailyAllowance.policyForEditing(at: now),
                    currentEnabled: policy.isEnabled,
                    onCancel: { isEditing = false },
                    onSaved: { isEditing = false }
                )
            } else {
                HStack {
                    Text("Always Lock").font(.headline.bold()).foregroundStyle(AppTheme.navy)
                        .accessibilityIdentifier("always-lock-row")
                    Spacer()
                    Text(statusText(state))
                        .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.steel)
                }
                HStack {
                    Spacer()
                    Button("Edit") { isEditing = true }
                        .accessibilityIdentifier("always-lock-edit-button")
                }
                if policy.isEnabled {
                    Text(L10n.format("Today's allowance: %d min remaining", model.dailyAllowanceRemainingMinutes))
                        .font(.title3.bold().monospacedDigit()).foregroundStyle(AppTheme.navy)
                        .accessibilityIdentifier("daily-allowance-balance")
                }
                Text(L10n.format("Daily limit: %d min", policy.dailyLimitMinutes))
                    .font(.caption).foregroundStyle(AppTheme.steel)
                stateActions(state)
                pendingChange
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showsPaidUnlockSheet) {
            PaidDailyAllowanceUnlockSheet(
                price: wakePurchaseStore.dailyAllowanceDisplayPrice,
                onPurchase: { minutes in
                    guard await model.beginDailyAllowancePurchase(minutes: minutes) else { return }
                    await wakePurchaseStore.purchaseDailyAllowanceUnlock { product in
                        try await purchase(product)
                    }
                }
            )
            .environmentObject(model)
        }
    }

    @ViewBuilder
    private func stateActions(_ state: DailyAllowanceAccessState) -> some View {
        switch state {
            case let .temporarilyUnlocked(grant):
                Text(grant.isPurchased ? "Purchased temporary unlock" : "Temporarily unlocked")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.steel)
                Text(L10n.format("Relocks at %@", dailyAllowanceExpiryDisplay(grant.expiresAt)))
                    .font(.caption).foregroundStyle(AppTheme.steel)
                Button("End temporary unlock") { Task { _ = await model.endDailyAllowanceGrant(id: grant.id) } }
                    .buttonStyle(.borderedProminent).disabled(model.isUpdatingLock)
            case .available:
                HStack {
                    ForEach(model.availableDailyAllowanceDurations, id: \.self) { minutes in
                        Button(L10n.format("%d min unlock", minutes)) { Task { _ = await model.beginDailyAllowanceGrant(minutes: minutes) } }
                            .buttonStyle(.bordered).disabled(model.isUpdatingLock)
                            .accessibilityIdentifier("daily-allowance-grant-\(minutes)")
                    }
                }
                Text("End early to return each full unused minute.")
                    .font(.caption).foregroundStyle(AppTheme.steel)
                paidUnlockAction
            case .blockedByNormalLock:
                if let grant = model.activeDailyAllowanceGrant {
                    Text("Regular lock prevents access to these targets.")
                        .font(.caption).foregroundStyle(AppTheme.steel)
                    Text(L10n.format("Relocks at %@", dailyAllowanceExpiryDisplay(grant.expiresAt)))
                        .font(.caption).foregroundStyle(AppTheme.steel)
                    Button("End temporary unlock") { Task { _ = await model.endDailyAllowanceGrant(id: grant.id) } }
                        .buttonStyle(.borderedProminent).disabled(model.isUpdatingLock)
                } else {
                    Text("Regular lock prevents access to these targets. No allowance was used.")
                        .font(.caption).foregroundStyle(AppTheme.steel)
                }
            case .exhausted:
                Text("Resets tomorrow at 12:00 AM").font(.caption).foregroundStyle(AppTheme.steel)
                paidUnlockAction
            case .dayBoundaryTooClose:
                Text("Unlock requests are closed for today.").font(.caption).foregroundStyle(AppTheme.steel)
                Text("Resets at 12:00 AM").font(.caption).foregroundStyle(AppTheme.steel)
            case .disabled:
                Text("Stopped")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.steel)
            case .notConfigured:
                EmptyView()
        }
    }

    @ViewBuilder
    private var paidUnlockAction: some View {
        Button {
            showsPaidUnlockSheet = true
        } label: {
            Label("Choose unlock time", systemImage: "creditcard")
        }
        .buttonStyle(.bordered)
        .disabled(!wakePurchaseStore.isDailyAllowancePurchaseAvailable || wakePurchaseStore.isPurchasing || model.isUpdatingLock)
        .accessibilityIdentifier("daily-allowance-paid-unlock-button")
    }

    @ViewBuilder
    private var pendingChange: some View {
        if let pending = model.lockState.dailyAllowance.pendingPolicy {
            Text(pending.policy.isEnabled
                ? L10n.format("Tomorrow: daily limit %d min", pending.policy.dailyLimitMinutes)
                : L10n.string("Tomorrow: stopped"))
                .font(.caption).foregroundStyle(AppTheme.steel)
            Text(L10n.format("Tomorrow's target: %@", pending.policy.targetSelection?.displayName ?? L10n.string("No targets selected")))
                .font(.caption).foregroundStyle(AppTheme.steel)
        }
    }

    private func statusText(_ state: DailyAllowanceAccessState) -> String {
        switch state {
        case .temporarilyUnlocked: return L10n.string("Temporarily unlocked")
        case .blockedByNormalLock: return L10n.string("Regular lock active")
        case .exhausted, .dayBoundaryTooClose, .available: return L10n.string("Locked")
        case .disabled: return L10n.string("Stopped")
        case .notConfigured: return L10n.string("Not configured")
        }
    }
}

private struct PaidDailyAllowanceUnlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: BearLockAppModel
    @State private var durationMinutes = 30.0

    let price: String?
    let onPurchase: (Int) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DurationPickerControl(
                        minutes: $durationMinutes,
                        minimumMinutes: 15,
                        maximumMinutes: 1_440,
                        stepMinutes: 15,
                        title: "Unlock duration",
                        minimumDurationHint: "Unlocks are available for 15 minutes or longer."
                    )
                    let expiry = Date().addingTimeInterval(TimeInterval(Int(durationMinutes) * 60))
                    Text(L10n.format("Relocks at %@", dailyAllowanceExpiryDisplay(expiry)))
                        .font(.caption).foregroundStyle(AppTheme.steel)
                }
                Section {
                    Text("This purchase does not use today's allowance. Bear Lock returns when the selected time ends.")
                        .font(.footnote).foregroundStyle(AppTheme.steel)
                }
                Section {
                    Button(price.map { L10n.format("Purchase timed unlock (%@)", $0) } ?? L10n.string("Purchase timed unlock")) {
                        Task {
                            await onPurchase(Int(durationMinutes))
                            dismiss()
                        }
                    }
                    .disabled(price == nil || model.isUpdatingLock)
                    .accessibilityIdentifier("paid-daily-unlock-confirm")
                }
            }
            .navigationTitle("Time-limited unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#if DEBUG
struct PaidUnlockReviewScreenshot: View {
    @EnvironmentObject private var model: BearLockAppModel

    var body: some View {
        ScheduledLockListView()
            .sheet(isPresented: .constant(true)) {
                PaidDailyAllowanceUnlockSheet(price: "¥500", onPurchase: { _ in })
                    .environmentObject(model)
            }
    }
}
#endif

private func dailyAllowanceExpiryDisplay(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
        return date.formatted(date: .omitted, time: .shortened)
    }
    return date.formatted(date: .abbreviated, time: .shortened)
}

private enum ScheduledLockEditSheet: Identifiable {
    case oneShot(LockRule)
    case recurring(LockRule)

    var id: String {
        switch self {
        case let .oneShot(rule):
            return "one-shot-\(rule.id.uuidString)"
        case let .recurring(rule):
            return "recurring-\(rule.id.uuidString)"
        }
    }
}

private struct ScheduledLockRow: View {
    let rule: LockRule
    let canEdit: Bool
    let now: Date
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCancelDeletion: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(AppTheme.steel)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.navy)
                if let interval = rule.displayInterval(at: now) {
                    Text("\(interval.start.formatted(date: .abbreviated, time: .shortened)) -> \(interval.end.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.navy.opacity(0.62))
                }
                if let deletion = rule.scheduledDeletionAt {
                    Text(L10n.format("Deletion scheduled for %@. This lock will continue until then.",
                        deletion.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(AppTheme.steel)
                        .accessibilityIdentifier("scheduled-lock-deletion-summary")
                } else if !canEdit {
                    Text(LocalizedStringKey(rule.kind == .recurring ? "Active. Deleting this schedule takes effect when this lock ends." : "This lock is active. Changes are available after it ends."))
                        .font(.caption)
                        .foregroundStyle(AppTheme.navy.opacity(0.72))
                }
                if rule.status == .disabled {
                    Text("Off")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.steel)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!canEdit)
                .accessibilityLabel("Edit scheduled lock")
                .accessibilityIdentifier("scheduled-lock-edit-button")

                if rule.scheduledDeletionAt == nil {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(rule.kind != .recurring && !canEdit)
                    .accessibilityLabel("Delete scheduled lock")
                    .accessibilityIdentifier("scheduled-lock-delete-button")
                } else {
                    Button {
                        onCancelDeletion()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Cancel scheduled deletion")
                    .accessibilityIdentifier("scheduled-lock-deletion-cancel-button")
                }
            }
        }
        .padding(14)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch rule.kind {
        case .immediate: return "Now"
        case .delayed: return "Starts later"
        case .fixedDateTime: return "Date & Time"
        case .recurring: return "Repeats"
        }
    }

    private var iconName: String {
        rule.kind == .recurring ? "repeat" : "calendar"
    }
}

private extension LockRule {
    func displayInterval(at date: Date) -> DateInterval? {
        nextInterval(after: date) ?? single?.interval
    }
}
