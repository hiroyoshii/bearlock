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
        _durationMinutes = State(initialValue: max(15, rule.duration / 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("予定") {
                    DatePicker("Starts", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("\(Int(durationMinutes)) min", value: $durationMinutes, in: 15...720, step: 15)
                }

                Section("確認") {
                    LabeledContent("Wakes") {
                        Text(endsAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("開始前の予定だけ編集できます。開始後は短縮、削除、対象アプリ削減はできません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Hibernation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(startsAt, durationMinutes * 60)
                    }
                    .disabled(isSaving || startsAt <= Date())
                }
            }
        }
    }

    private var endsAt: Date {
        startsAt.addingTimeInterval(durationMinutes * 60)
    }
}
