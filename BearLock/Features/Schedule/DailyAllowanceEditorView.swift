import BearLockCore
import FamilyControls
import SwiftUI

struct DailyAllowanceEditorView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @State private var policy: DailyAllowancePolicy
    @State private var selection = FamilyActivitySelection()
    @State private var showsTargetPicker = false
    @State private var errorMessage: String?

    let currentEnabled: Bool
    let onCancel: () -> Void
    let onSaved: () -> Void

    init(
        policy: DailyAllowancePolicy,
        currentEnabled: Bool,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        _policy = State(initialValue: policy)
        self.currentEnabled = currentEnabled
        self.onCancel = onCancel
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Edit Always Lock")
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
                    .accessibilityIdentifier("daily-allowance-inline-editor-title")
                Spacer()
                Button("Cancel", action: onCancel)
                    .disabled(model.isUpdatingLock)
            }

            Button { showsTargetPicker = true } label: {
                LabeledContent("Target") {
                    Text(targetName).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("daily-allowance-edit-target")

            Picker("Daily allowance", selection: $policy.dailyLimitMinutes) {
                ForEach([15, 30, 60, 90, 120], id: \.self) { minutes in
                    Text(L10n.format("%d minutes", minutes)).tag(minutes)
                }
            }
            .accessibilityIdentifier("daily-allowance-edit-limit-picker")

            Text(L10n.format("Changes take effect %@. Today's lock remains active.", effectiveDate.formatted(date: .abbreviated, time: .omitted)))
                .font(.caption)
                .foregroundStyle(AppTheme.steel)
                .accessibilityIdentifier("daily-allowance-effective-date")

            HStack {
                Button(currentEnabled ? "Stop Tomorrow" : "Restart Tomorrow") {
                    var updated = policy
                    updated.isEnabled = !currentEnabled
                    save(updated)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(currentEnabled ? "daily-allowance-stop" : "daily-allowance-restart")

                Spacer()

                Button("Schedule Changes") { save(policy) }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.navy)
                    .disabled(model.isUpdatingLock || !hasTarget)
                    .accessibilityIdentifier("daily-allowance-save-changes")
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .familyActivityPicker(isPresented: $showsTargetPicker, selection: $selection)
        .task {
            do { selection = try model.dailyAllowanceActivitySelection() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private var effectiveDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var hasTarget: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty || policy.targetSelection?.tokenData != nil
    }

    private var targetName: String {
        let count = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        if count > 0 { return L10n.format("%d targets", count) }
        return policy.targetSelection?.displayName ?? L10n.string("No targets selected")
    }

    private func save(_ updated: DailyAllowancePolicy) {
        errorMessage = nil
        Task {
            let result = await model.saveDailyAllowancePolicy(updated, selection: selection)
            if result.isSaved {
                onSaved()
            } else {
                errorMessage = model.lastErrorMessage ?? L10n.string("Could not save settings.")
            }
        }
    }
}
