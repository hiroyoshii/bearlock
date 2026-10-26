import BearLockCore
import SwiftUI

struct ScheduledLockListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var pendingDeletion: LockRule?
    @State private var showsDeleteConfirmation = false
    @State private var editingSheet: ScheduledLockEditSheet?
    @State private var saveError: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text("Scheduled Locks")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)

                if scheduledRules(at: context.date).isEmpty {
                    Text("No scheduled locks.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.navy.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(scheduledRules(at: context.date)) { rule in
                        ScheduledLockRow(
                            rule: rule,
                            canEdit: canEdit(rule, at: context.date),
                            now: context.date,
                            onEdit: {
                                saveError = nil
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
            Group {
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
                                finishSaving(didUpdate)
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
                                finishSaving(didUpdate)
                            }
                        }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let saveError {
                    Text(saveError).foregroundStyle(.red).padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .accessibilityIdentifier("schedule-save-error")
                }
            }
        }
    }

    private func finishSaving(_ outcome: OperationOutcome) {
        if outcome.isSaved { editingSheet = nil }
        else {
            saveError = model.lastErrorMessage
            model.lastErrorMessage = nil
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
