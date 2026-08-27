import BearLockCore
import SwiftUI

enum LockComposerMode: String, CaseIterable, Identifiable {
    case now = "Now"
    case delayed = "In"
    case fixedDateTime = "Date"
    case recurring = "Repeat"

    var id: String { rawValue }
}

struct LockComposerView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @Binding var mode: LockComposerMode

    @State private var delayMinutes = 30.0
    @State private var durationMinutes = 120.0
    @State private var fixedStart = Date().addingTimeInterval(30 * 60)
    @State private var recurringStart = DateComponents(hour: 23, minute: 0)
    @State private var recurringEnd = DateComponents(hour: 7, minute: 0)
    @State private var selectedWeekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var confirmationDetails: LockConfirmationDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Start", selection: $mode) {
                ForEach(LockComposerMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("lock-composer-mode-picker")

            Group {
                switch mode {
                case .now:
                    durationControl
                case .delayed:
                    delayControl
                    durationControl
                    scheduleSummary
                case .fixedDateTime:
                    DatePicker("Starts", selection: $fixedStart, displayedComponents: [.date, .hourAndMinute])
                    durationControl
                    scheduleSummary
                case .recurring:
                    weekdayControl
                    timePicker(title: "Starts", components: $recurringStart)
                    timePicker(title: "Ends", components: $recurringEnd)
                }
            }

            Button {
                confirmationDetails = makeConfirmationDetails()
            } label: {
                Label(primaryButtonTitle, systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.navy)
            .disabled(!canSubmit)
            .accessibilityIdentifier("lock-composer-primary-button")
        }
        .padding(16)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        .sheet(item: confirmationBinding) { details in
            LockConfirmationSheet(
                details: details,
                isSubmitting: model.isCreatingLock,
                onCancel: {
                    confirmationDetails = nil
                },
                onConfirm: {
                    Task {
                        let didCreate = await model.createLock(makeRequest())
                        if didCreate {
                            confirmationDetails = nil
                        }
                    }
                }
            )
        }
    }

    private var durationControl: some View {
        VStack(alignment: .leading) {
            Text("Duration")
                .font(.headline)
            Stepper("\(Int(durationMinutes)) min", value: $durationMinutes, in: 15...720, step: 15)
        }
    }

    private var delayControl: some View {
        VStack(alignment: .leading) {
            Text("Starts in")
                .font(.headline)
            Stepper("\(Int(delayMinutes)) min", value: $delayMinutes, in: 5...240, step: 5)
        }
    }

    private var weekdayControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekdays")
                .font(.headline)

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
    }

    private var scheduleSummary: some View {
        let start = mode == .delayed ? Date().addingTimeInterval(delayMinutes * 60) : fixedStart
        let end = start.addingTimeInterval(durationMinutes * 60)

        return VStack(alignment: .leading, spacing: 4) {
            Text("Starts \(start.formatted(date: .abbreviated, time: .shortened))")
            Text("Wakes \(end.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.navy.opacity(0.68))
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

    private var primaryButtonTitle: String {
        mode == .now ? "Hibernate" : "Schedule Hibernation"
    }

    private var canSubmit: Bool {
        guard model.lockState.targetSelections.last != nil else {
            return false
        }

        if mode == .recurring {
            return !selectedWeekdays.isEmpty
        }

        return true
    }

    private func makeRequest() -> LockCreationRequest {
        let targetID = model.lockState.targetSelections.last?.id ?? UUID()
        switch mode {
        case .now:
            return .now(duration: durationMinutes * 60, targetSelectionID: targetID)
        case .delayed:
            return .delayed(delay: delayMinutes * 60, duration: durationMinutes * 60, targetSelectionID: targetID)
        case .fixedDateTime:
            return .fixed(startsAt: fixedStart, duration: durationMinutes * 60, targetSelectionID: targetID)
        case .recurring:
            return .recurring(
                recurrence: RecurrenceRule(
                    weekdays: selectedWeekdays,
                    startsAt: TimeOfDay(hour: recurringStart.hour ?? 23, minute: recurringStart.minute ?? 0),
                    endsAt: TimeOfDay(hour: recurringEnd.hour ?? 7, minute: recurringEnd.minute ?? 0)
                ),
                targetSelectionID: targetID
            )
        }
    }

    private func makeConfirmationDetails() -> LockConfirmationDetails {
        let startsAt: Date
        let endsAt: Date

        switch mode {
        case .now:
            startsAt = Date()
            endsAt = startsAt.addingTimeInterval(durationMinutes * 60)
        case .delayed:
            startsAt = Date().addingTimeInterval(delayMinutes * 60)
            endsAt = startsAt.addingTimeInterval(durationMinutes * 60)
        case .fixedDateTime:
            startsAt = fixedStart
            endsAt = startsAt.addingTimeInterval(durationMinutes * 60)
        case .recurring:
            let recurrence = RecurrenceRule(
                weekdays: selectedWeekdays,
                startsAt: TimeOfDay(hour: recurringStart.hour ?? 23, minute: recurringStart.minute ?? 0),
                endsAt: TimeOfDay(hour: recurringEnd.hour ?? 7, minute: recurringEnd.minute ?? 0)
            )
            let interval = recurrence.nextInterval(after: Date())
            startsAt = interval?.start ?? Date()
            endsAt = interval?.end ?? startsAt.addingTimeInterval(recurrence.duration)
        }

        return LockConfirmationDetails(
            title: mode == .now ? "Bear will sleep now." : "Schedule Bear's sleep.",
            targetSummary: model.lockState.targetSelections.last?.displayName ?? "Selected apps",
            startsAt: startsAt,
            endsAt: endsAt,
            isImmediate: mode == .now
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

    private var confirmationBinding: Binding<LockConfirmationDetails?> {
        Binding(
            get: { confirmationDetails },
            set: { confirmationDetails = $0 }
        )
    }
}

extension LockConfirmationDetails: Identifiable {
    var id: String {
        "\(startsAt.timeIntervalSince1970)-\(endsAt.timeIntervalSince1970)-\(targetSummary)"
    }
}
