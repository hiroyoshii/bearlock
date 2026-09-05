import BearLockCore
import FamilyControls
import SwiftUI

struct FrequentTargetListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var pendingDeletion: RecentLockTarget?

    var body: some View {
        if !displayedTargets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Frequently used targets")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)

                VStack(spacing: 0) {
                    ForEach(Array(displayedTargets.enumerated()), id: \.element.id) { index, recentTarget in
                        if index > 0 {
                            Divider()
                                .overlay(AppTheme.navy.opacity(0.1))
                                .padding(.leading, 14)
                        }

                        if let selection = selection(for: recentTarget) {
                            FrequentTargetRow(
                                recentTarget: recentTarget,
                                selection: selection,
                                isSelected: model.lockState.targetSelections.last?.id == selection.id,
                                onSelect: {
                                    Task {
                                        await model.selectRecentLockTarget(recentTarget)
                                    }
                                },
                                onSetPinned: { pinned in
                                    Task {
                                        await model.setRecentLockTargetPinned(recentTarget, pinned: pinned)
                                    }
                                },
                                onDelete: {
                                    pendingDeletion = recentTarget
                                }
                            )
                        }
                    }
                }
                .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
            }
            .confirmationDialog(
                "Remove from frequent targets?",
                isPresented: deletionConfirmationBinding,
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { recentTarget in
                Button("Remove", role: .destructive) {
                    Task {
                        await model.deleteRecentLockTarget(recentTarget)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Existing schedules and the active lock will not change.")
            }
        }
    }

    private var displayedTargets: [RecentLockTarget] {
        model.lockState.displayedRecentLockTargets(limit: 3)
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func selection(for recentTarget: RecentLockTarget) -> LockTargetSelectionRef? {
        model.lockState.targetSelections.last { $0.id == recentTarget.targetSelectionID }
    }
}

private struct FrequentTargetRow: View {
    let recentTarget: RecentLockTarget
    let selection: LockTargetSelectionRef
    let isSelected: Bool
    let onSelect: () -> Void
    let onSetPinned: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    RecentTargetSummary(selection: selection)

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.navy)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isSelected ? Text("Selected") : Text("Not selected"))
            .accessibilityHint("Use this saved target")
            .accessibilityIdentifier("frequent-target-select-\(recentTarget.id.uuidString)")

            Button {
                onSetPinned(!recentTarget.isPinned)
            } label: {
                Image(systemName: recentTarget.isPinned ? "pin.fill" : "pin")
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(recentTarget.isPinned ? AppTheme.navy : AppTheme.steel)
            .accessibilityLabel(
                Text(LocalizedStringKey(recentTarget.isPinned ? "Unpin target" : "Pin target"))
            )
            .accessibilityIdentifier("frequent-target-pin-\(recentTarget.id.uuidString)")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("Remove target")
            .accessibilityIdentifier("frequent-target-delete-\(recentTarget.id.uuidString)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.ice.opacity(0.55) : Color.clear)
    }
}

private struct RecentTargetSummary: View {
    let selection: LockTargetSelectionRef

    private var decodedSelection: FamilyActivitySelection? {
        guard let tokenData = selection.tokenData else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: tokenData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            primaryLabel
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.navy)
                .lineLimit(1)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(AppTheme.navy.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryLabel: some View {
        if let token = decodedSelection?.applicationTokens.first {
            Label(token)
                .labelStyle(RecentTargetTokenLabelStyle())
                .environment(\.colorScheme, .light)
        } else if let token = decodedSelection?.categoryTokens.first {
            Label(token)
                .labelStyle(RecentTargetTokenLabelStyle())
                .environment(\.colorScheme, .light)
        } else if let token = decodedSelection?.webDomainTokens.first {
            Label(token)
                .labelStyle(RecentTargetTokenLabelStyle())
                .environment(\.colorScheme, .light)
        } else {
            Text(selection.displayName)
        }
    }

    private var summaryText: String {
        guard let decodedSelection else {
            return L10n.string("Saved target")
        }

        let count = decodedSelection.applicationTokens.count
            + decodedSelection.categoryTokens.count
            + decodedSelection.webDomainTokens.count
        return L10n.format("%d targets", count)
    }
}

private struct RecentTargetTokenLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            configuration.title
                .foregroundStyle(AppTheme.navy)
        }
    }
}
