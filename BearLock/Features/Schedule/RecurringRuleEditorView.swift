import BearLockCore
import SwiftUI

struct RecurringRuleEditorView: View {
    let rule: LockRule
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (_ recurrence: RecurrenceRule, _ enabled: Bool) -> Void

    @State private var selectedWeekdays: Set<Weekday>
    @State private var startsAt: DateComponents
    @State private var endsAt: DateComponents
    @State private var isEnabled: Bool

    init(
        rule: LockRule,
        isSaving: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ recurrence: RecurrenceRule, _ enabled: Bool) -> Void
    ) {
        self.rule = rule
        self.isSaving = isSaving
        self.onCancel = onCancel
        self.onSave = onSave

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
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let isActive = rule.status == .scheduled && rule.occurrence(containing: context.date) != nil
            NavigationStack {
                Form {
                    Section("Status") {
                        Toggle("Enabled", isOn: $isEnabled)
                            .disabled(isSaving || isActive)
                            .accessibilityIdentifier("recurring-rule-enabled-toggle")
                    }

                    Section("Weekdays") {
                        weekdayGrid
                            .disabled(isSaving || isActive)
                    }

                    Section("Time") {
                        timePicker(title: "Starts", components: $startsAt)
                            .disabled(isSaving || isActive)
                        timePicker(title: "Ends", components: $endsAt)
                            .disabled(isSaving || isActive)
                        LabeledContent("Next") {
                            Text(nextIntervalText)
                        }
                        if let safetyLimitText {
                            Label(safetyLimitText, systemImage: "exclamationmark.shield")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.steel)
                        }
                    }

                    Section {
                        Text("Times and weekdays cannot be changed during a lock. Deletion takes effect when the current lock ends.")
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
                            onSave(makeRecurrence(), isEnabled)
                        }
                        .disabled(isActive || isSaving || selectedWeekdays.isEmpty || isOverSafetyLimit)
                    }
                }
            }
        }
    }

    private var weekdayGrid: some View {
        HStack {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                Button(weekday.shortName()) {
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
            return L10n.string("No upcoming hibernation")
        }
        return "\(interval.start.formatted(date: .abbreviated, time: .shortened)) -> \(interval.end.formatted(date: .abbreviated, time: .shortened))"
    }

    private var isOverSafetyLimit: Bool {
        guard let maximumDuration = BearLockSafetyPolicy.maximumDuration else {
            return false
        }
        return makeRecurrence().duration > maximumDuration
    }

    private var safetyLimitText: String? {
        guard let maximumDuration = BearLockSafetyPolicy.maximumDuration else {
            return nil
        }
        return L10n.format("Debug safety limit: max %d min", Int(maximumDuration / 60))
    }

    private func makeRecurrence() -> RecurrenceRule {
        RecurrenceRule(
            weekdays: selectedWeekdays,
            startsAt: TimeOfDay(hour: startsAt.hour ?? 23, minute: startsAt.minute ?? 0),
            endsAt: TimeOfDay(hour: endsAt.hour ?? 7, minute: endsAt.minute ?? 0),
            calendarIdentifier: rule.recurrence?.calendarIdentifier ?? .gregorian,
            timeZoneIdentifier: rule.recurrence?.timeZoneIdentifier ?? TimeZone.current.identifier
        )
    }

    private func timePicker(title: String, components: Binding<DateComponents>) -> some View {
        DatePicker(
            LocalizedStringKey(title),
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

}
