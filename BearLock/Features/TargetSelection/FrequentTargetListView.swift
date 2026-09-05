import BearLockCore
import FamilyControls
import SwiftUI

struct FrequentTargetListView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var pendingDeletion: RecentLockTarget?
    @State private var isExpanded = false

    var body: some View {
        if !displayedTargets.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Recent targets")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(displayedTargets.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.navy.opacity(0.55))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundStyle(AppTheme.navy.opacity(0.72))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(LocalizedStringKey(isExpanded ? "Hide recent targets" : "Show recent targets"))
                )
                .accessibilityIdentifier("recent-targets-disclosure")

                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(displayedTargets) { recentTarget in
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .confirmationDialog(
                "Remove from recent targets?",
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
                        Text("Selected")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.snow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.navy, in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(RecentTargetSelectionButtonStyle())
            .accessibilityValue(isSelected ? Text("Selected") : Text("Not selected"))
            .accessibilityHint("Use this saved target")
            .accessibilityIdentifier("frequent-target-select-\(recentTarget.id.uuidString)")

            Menu {
                Button {
                    onSetPinned(!recentTarget.isPinned)
                } label: {
                    Label(
                        recentTarget.isPinned ? "Unpin target" : "Pin target",
                        systemImage: recentTarget.isPinned ? "pin.slash" : "pin"
                    )
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Remove target", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.navy.opacity(0.68))
            .accessibilityLabel("Target actions")
            .accessibilityIdentifier("frequent-target-actions-\(recentTarget.id.uuidString)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.ice : AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppTheme.navy : AppTheme.navy.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        }
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

private struct RecentTargetSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
