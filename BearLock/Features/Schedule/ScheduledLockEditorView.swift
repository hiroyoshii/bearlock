import BearLockCore
import SwiftUI

struct ScheduledLockEditorView: View {
    let rule: LockRule
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (_ startsAt: Date, _ duration: TimeInterval) -> Void

    @State private var startsAt: Date
    @State private var durationMinutes: Double

    init(
        rule: LockRule,
        isSaving: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ startsAt: Date, _ duration: TimeInterval) -> Void
    ) {
        self.rule = rule
        self.isSaving = isSaving
        self.onCancel = onCancel
        self.onSave = onSave
        _startsAt = State(initialValue: rule.startsAt)
        let initialDuration = rule.duration / 60
        let lowerBound = BearLockSafetyPolicy.maximumDuration == nil ? 15.0 : 5.0
        let upperBound = BearLockSafetyPolicy.maximumDuration.map { max(5.0, $0 / 60) } ?? 720.0
        _durationMinutes = State(initialValue: min(max(lowerBound, initialDuration), upperBound))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    DatePicker("Starts", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    DurationPickerControl(
                        minutes: $durationMinutes,
                        minimumMinutes: minimumDurationMinutes,
                        maximumMinutes: maximumDurationMinutes
                    )
                }

                Section("Confirmation") {
                    LabeledContent("Wakes") {
                        Text(endsAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let safetyLimitText {
                        Label(safetyLimitText, systemImage: "exclamationmark.shield")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.steel)
                    }
                    Text("Scheduled locks can only be edited before they start. After start, they cannot be shortened, deleted, or have target apps reduced.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Lock")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(startsAt, durationMinutes * 60)
                    }
                    .disabled(isSaving || startsAt <= Date() || isOverSafetyLimit)
                }
            }
        }
    }

    private var endsAt: Date {
        startsAt.addingTimeInterval(durationMinutes * 60)
    }

    private var minimumDurationMinutes: Double {
        BearLockSafetyPolicy.maximumDuration == nil ? 15 : 5
    }

    private var maximumDurationMinutes: Double {
        BearLockSafetyPolicy.maximumDuration.map { max(5.0, $0 / 60) } ?? 720
    }

    private var isOverSafetyLimit: Bool {
        guard let maximumDuration = BearLockSafetyPolicy.maximumDuration else {
            return false
        }
        return durationMinutes * 60 > maximumDuration
    }

    private var safetyLimitText: String? {
        guard let maximumDuration = BearLockSafetyPolicy.maximumDuration else {
            return nil
        }
        return L10n.format("Debug safety limit: max %d min", Int(maximumDuration / 60))
    }
}
