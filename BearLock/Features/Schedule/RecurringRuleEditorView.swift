import BearLockCore
import SwiftUI

struct RecurringRuleEditorView: View {
    let rule: LockRule
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (_ recurrence: RecurrenceRule) -> Void
    let onSetEnabled: (_ enabled: Bool) -> Void

    @State private var selectedWeekdays: Set<Weekday>
    @State private var startsAt: DateComponents
    @State private var endsAt: DateComponents
    @State private var isEnabled: Bool

    init(
        rule: LockRule,
        isSaving: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ recurrence: RecurrenceRule) -> Void,
        onSetEnabled: @escaping (_ enabled: Bool) -> Void
    ) {
        self.rule = rule
        self.isSaving = isSaving
        self.onCancel = onCancel
        self.onSave = onSave
        self.onSetEnabled = onSetEnabled

        let recurrence = rule.recurrence ?? RecurrenceRule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0)
        )
        _selectedWeekdays = State(initialValue: recurrence.weekdays)
        _startsAt = State(initialValue: DateComponents(hour: recurrence.startsAt.hour, minute: recurrence.startsAt.minute))
        _endsAt = State(initialValue: DateComponents(hour: recurrence.endsAt.hour, minute: recurrence.endsAt.minute))
        _isEnabled = State(initialValue: rule.status == .scheduled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("状態") {
                    Toggle("Enabled", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, enabled in
                            onSetEnabled(enabled)
                        }
                        .accessibilityIdentifier("recurring-rule-enabled-toggle")
                }

                Section("曜日") {
                    weekdayGrid
                }

                Section("時刻") {
                    timePicker(title: "Starts", components: $startsAt)
                    timePicker(title: "Ends", components: $endsAt)
                    LabeledContent("Next") {
                        Text(nextIntervalText)
                    }
                }

                Section {
                    Text("Recurring ruleの変更は次回以降に反映されます。現在実行中のActiveLockは短縮・解除されません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Repeat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(makeRecurrence())
                    }
                    .disabled(isSaving || selectedWeekdays.isEmpty)
                }
            }
        }
    }

    private var weekdayGrid: some View {
        HStack {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                Button(shortName(for: weekday)) {
                    if selectedWeekdays.contains(weekday) {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                }
                .buttonStyle(.bordered)
                .tint(selectedWeekdays.contains(weekday) ? AppTheme.navy : AppTheme.steel)
            }
        }
    }

    private var nextIntervalText: String {
        guard let interval = makeRecurrence().nextInterval(after: Date()) else {
            return "No upcoming hibernation"
        }
        return "\(interval.start.formatted(date: .abbreviated, time: .shortened)) -> \(interval.end.formatted(date: .abbreviated, time: .shortened))"
    }

    private func makeRecurrence() -> RecurrenceRule {
        RecurrenceRule(
            weekdays: selectedWeekdays,
            startsAt: TimeOfDay(hour: startsAt.hour ?? 23, minute: startsAt.minute ?? 0),
            endsAt: TimeOfDay(hour: endsAt.hour ?? 7, minute: endsAt.minute ?? 0)
        )
    }

    private func timePicker(title: String, components: Binding<DateComponents>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { date(from: components.wrappedValue) },
                set: { components.wrappedValue = Calendar.current.dateComponents([.hour, .minute], from: $0) }
            ),
            displayedComponents: [.hourAndMinute]
        )
    }

    private func date(from components: DateComponents) -> Date {
        var base = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        base.hour = components.hour
        base.minute = components.minute
        return Calendar.current.date(from: base) ?? Date()
    }

    private func shortName(for weekday: Weekday) -> String {
        switch weekday {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }
}
