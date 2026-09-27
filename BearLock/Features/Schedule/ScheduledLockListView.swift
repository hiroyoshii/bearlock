import BearLockCore
import SwiftUI

struct ScheduledLockListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var pendingDeletion: LockRule?
    @State private var showsDeleteConfirmation = false
    @State private var editingSheet: ScheduledLockEditSheet?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 12) {
                Text("Scheduled Locks")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)

                if scheduledRules.isEmpty {
                    Text("No scheduled locks.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.navy.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(scheduledRules) { rule in
                        ScheduledLockRow(
                            rule: rule,
                            canEdit: canEdit(rule),
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
                            }
                        )
                    }
                }
            }
        }
        .confirmationDialog("Delete this schedule?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let rule = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await model.deleteScheduledRule(rule) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            if pendingDeletion?.kind == .recurring {
                Text("Deleting this schedule also ends its active lock. Other schedules will keep blocking their targets.")
            } else if let interval = pendingDeletion?.displayInterval {
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
                            if didUpdate {
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
                            if didUpdate {
                                editingSheet = nil
                            }
                        }
                    }
                )
            }
        }
    }

    private var scheduledRules: [LockRule] {
        model.lockState.rules
            .filter { $0.kind != .immediate && (!$0.isOneShot || $0.single!.endsAt > Date()) }
            .sorted { ($0.displayInterval?.start ?? .distantFuture) < ($1.displayInterval?.start ?? .distantFuture) }
    }

    private func canEdit(_ rule: LockRule) -> Bool {
        (try? model.lockState.validateEditable(rule, at: Date())) != nil &&
            (rule.kind == .recurring || rule.single!.startsAt > Date())
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
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(AppTheme.steel)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.navy)
                if let interval = rule.displayInterval {
                    Text("\(interval.start.formatted(date: .abbreviated, time: .shortened)) -> \(interval.end.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.navy.opacity(0.62))
                }
                if !canEdit {
                    Text(LocalizedStringKey(rule.kind == .recurring ? "Active. You can delete this schedule to end its lock." : "This lock is active. Changes are available after it ends."))
                        .font(.caption)
                        .foregroundStyle(AppTheme.steel)
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
                }
                .disabled(!canEdit)
                .accessibilityLabel("Edit scheduled lock")
                .accessibilityIdentifier("scheduled-lock-edit-button")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(rule.kind != .recurring && !canEdit)
                .accessibilityLabel("Delete scheduled lock")
                .accessibilityIdentifier("scheduled-lock-delete-button")
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
    var displayInterval: DateInterval? {
        nextInterval(after: Date()) ?? single?.interval
    }
}
