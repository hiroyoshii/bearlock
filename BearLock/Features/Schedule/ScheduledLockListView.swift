import BearLockCore
import SwiftUI

struct ScheduledLockListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var editingSheet: ScheduledLockEditSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Hibernation")
                .font(.headline)
                .foregroundStyle(AppTheme.navy)

            if scheduledRules.isEmpty {
                Text("予定された冬眠はありません。")
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
                            Task {
                                await model.deleteScheduledRule(rule)
                            }
                        }
                    )
                }
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
                    onSave: { recurrence in
                        Task {
                            let didUpdate = await model.updateRecurringRule(rule, recurrence: recurrence)
                            if didUpdate {
                                editingSheet = nil
                            }
                        }
                    },
                    onSetEnabled: { enabled in
                        Task {
                            await model.setRecurringRule(rule, enabled: enabled)
                        }
                    }
                )
            }
        }
    }

    private var scheduledRules: [LockRule] {
        model.lockState.rules
            .filter { $0.status == .scheduled || $0.status == .disabled }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func canEdit(_ rule: LockRule) -> Bool {
        rule.kind == .recurring || (rule.startsAt > Date() && (rule.kind == .delayed || rule.kind == .fixedDateTime))
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
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.navy)
                Text("\(rule.startsAt.formatted(date: .abbreviated, time: .shortened)) -> \(rule.endsAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.navy.opacity(0.62))
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
