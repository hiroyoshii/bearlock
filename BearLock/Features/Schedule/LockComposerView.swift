import BearLockCore
import FamilyControls
import SwiftUI

enum LockComposerMode: String, CaseIterable, Identifiable {
    case now = "Now"
    case delayed = "In"
    case fixedDateTime = "Date & Time"
    case always = "Always"

    var id: String { rawValue }
    var displayTitle: String { self == .fixedDateTime ? "Date mode" : rawValue }
}

private enum DateRepeatMode: String, CaseIterable, Identifiable {
    case none = "None"
    case weekdays = "Repeat weekdays"
    var id: String { rawValue }
}

struct LockComposerView: View {
    @EnvironmentObject private var model: BearLockAppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var mode: LockComposerMode
    var allowsImmediateLock = true
    var startsWithWeekdays = false

    @State private var delayMinutes = 30.0
    @State private var durationMinutes = 120.0
    @State private var fixedStart = Date().addingTimeInterval(30 * 60)
    @State private var repeatMode: DateRepeatMode = .none
    @State private var recurringStart = DateComponents(hour: 23, minute: 0)
    @State private var selectedWeekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var confirmationDetails: LockConfirmationDetails?
    @State private var dailyAllowanceLimitMinutes = 60
    @State private var allowanceSaveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let safetyLimitText {
                Label(safetyLimitText, systemImage: "exclamationmark.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.steel)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.ice, in: RoundedRectangle(cornerRadius: 8))
            }
            modePicker
            if mode == .always && !model.lockState.dailyAllowance.isConfigured {
                Text("Always lock every day and temporarily unlock within your daily allowance. Changes and stopping take effect tomorrow.")
                    .font(.caption).foregroundStyle(AppTheme.steel)
                    .accessibilityIdentifier("daily-allowance-overview")
            }
            if mode == .now && !allowsImmediateLock {
                Label("Cannot start now while a lock is active.", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.steel)
            }
            Group {
                switch mode {
                case .now:
                    durationControl
                case .delayed:
                    delayControl
                    durationControl
                    scheduleSummary
                case .fixedDateTime:
                    dateRepeatPicker
                    if repeatMode == .none {
                        ScheduleDatePicker(title: "Starts", selection: $fixedStart, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        weekdayControl
                        timePicker(title: "Starts", components: $recurringStart)
                            .accessibilityIdentifier("repeat-start-time")
                    }
                    durationControl
                    scheduleSummary
                case .always:
                    if model.lockState.dailyAllowance.isConfigured {
                        alwaysConfigured
                    } else {
                        alwaysCreationSettings
                    }
                }
            }
            if mode == .always && !model.lockState.dailyAllowance.isConfigured {
                Button {
                    Task { await saveAlwaysPolicy() }
                } label: {
                    Label("Start Always Lock", systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.navy)
                .disabled(!canSaveAlways || model.isUpdatingLock)
                .accessibilityIdentifier("lock-composer-primary-button")
                if let allowanceSaveError {
                    Text(allowanceSaveError).font(.caption).foregroundStyle(.red)
                }
            } else if mode != .always {
                Button {
                    confirmationDetails = makeConfirmationDetails()
                } label: {
                    Label(LocalizedStringKey(primaryButtonTitle), systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.navy)
                .disabled(!canSubmit)
                .accessibilityIdentifier("lock-composer-primary-button")
            }
        }
        .padding(16)
        .background(AppTheme.snow, in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            applySafetyDefaults()
            if startsWithWeekdays { repeatMode = .weekdays }
        }
        .sheet(item: confirmationBinding) { details in
            LockConfirmationSheet(details: details, isSubmitting: model.isCreatingLock, onCancel: { confirmationDetails = nil }, onConfirm: {
                Task {
                    if (await model.createLock(makeRequest())).isSaved { confirmationDetails = nil }
                }
            })
        }
    }

    private var dateRepeatPicker: some View {
        Picker("Repeat", selection: $repeatMode) {
            ForEach(DateRepeatMode.allCases) { option in Text(LocalizedStringKey(option.rawValue)).tag(option) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("date-repeat-picker")
    }

    private var alwaysCreationSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily allowance").font(.headline).foregroundStyle(AppTheme.navy)
                Text(L10n.format("%d minutes", dailyAllowanceLimitMinutes))
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.navy)
                    .accessibilityIdentifier("daily-allowance-selected-limit")
            }
            Picker("Daily allowance", selection: $dailyAllowanceLimitMinutes) {
                ForEach([15, 30, 60, 90, 120], id: \.self) { minutes in
                    Text(L10n.format("%d minutes", minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("daily-allowance-limit-picker")
        }
    }

    private var alwaysConfigured: some View {
        HStack {
            Label("Configured", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(AppTheme.navy)
            Spacer()
            Text(L10n.format("Daily limit: %d min", model.lockState.dailyAllowance.policyForEditing(at: Date()).dailyLimitMinutes))
                .font(.subheadline).foregroundStyle(AppTheme.steel)
        }
    }

    private var durationControl: some View {
        DurationPickerControl(minutes: $durationMinutes, minimumMinutes: minimumDurationMinutes, maximumMinutes: maximumDurationMinutes)
    }

    @ViewBuilder private var modePicker: some View {
        let picker = Picker("Start", selection: $mode) {
            ForEach(LockComposerMode.allCases) { option in
                Text(LocalizedStringKey(option.displayTitle))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel(Text(LocalizedStringKey(option.rawValue)))
                    .tag(option)
            }
        }
        .tint(AppTheme.navy)
        .accessibilityIdentifier("lock-composer-mode-picker")
        if dynamicTypeSize.isAccessibilitySize { picker.pickerStyle(.menu).frame(minHeight: 44) }
        else { picker.pickerStyle(.segmented).frame(minHeight: 44) }
    }

    private var delayControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Starts in").font(.headline).foregroundStyle(AppTheme.navy)
            HStack(spacing: 12) {
                Button { delayMinutes = max(5, delayMinutes - 5) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(.bordered).disabled(delayMinutes <= 5).accessibilityLabel("Decrease start delay")
                Text(L10n.format("%d min", Int(delayMinutes))).font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 54)
                Button { delayMinutes = min(240, delayMinutes + 5) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(.bordered).disabled(delayMinutes >= 240).accessibilityLabel("Increase start delay")
            }
        }
    }

    private var weekdayControl: some View {
        VStack(alignment: .leading, spacing: 8) { Text("Weekdays").font(.headline); WeekdayPicker(selection: $selectedWeekdays) }
    }

    private var scheduleSummary: some View {
        let interval: DateInterval
        if mode == .fixedDateTime, repeatMode == .weekdays {
            let recurrence = makeRecurrence()
            interval = recurrence.nextInterval(after: Date()) ?? DateInterval(start: Date(), duration: recurrence.duration)
        } else {
            let start = mode == .delayed ? Date().addingTimeInterval(delayMinutes * 60) : fixedStart
            interval = DateInterval(start: start, duration: durationMinutes * 60)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.format("Starts %@", interval.start.formatted(date: .abbreviated, time: .shortened)))
            Text(L10n.format("Wakes %@", interval.end.formatted(date: .abbreviated, time: .shortened)))
        }.font(.subheadline).foregroundStyle(AppTheme.navy.opacity(0.68))
    }

    private func timePicker(title: String, components: Binding<DateComponents>) -> some View {
        ScheduleDatePicker(title: title, selection: Binding(get: { date(from: components.wrappedValue) }, set: { components.wrappedValue = Calendar.current.dateComponents([.hour, .minute], from: $0) }), displayedComponents: [.hourAndMinute])
    }

    private var primaryButtonTitle: String { mode == .now ? "Start Lock" : "Schedule Lock" }
    private var canSaveAlways: Bool { model.authorizationStatus == .approved && model.lockState.selectedTarget?.tokenData != nil }
    private var canSubmit: Bool {
        guard model.authorizationStatus == .approved, model.lockState.selectedTarget != nil else { return false }
        if !allowsImmediateLock && mode == .now { return false }
        if let maximumDuration = BearLockSafetyPolicy.maximumDuration, requestDuration > maximumDuration { return false }
        if mode == .fixedDateTime && repeatMode == .weekdays { return !selectedWeekdays.isEmpty }
        return true
    }
    private var minimumDurationMinutes: Double { BearLockSafetyPolicy.maximumDuration == nil ? 15 : 5 }
    private var maximumDurationMinutes: Double { BearLockSafetyPolicy.maximumDuration.map { max(5, $0 / 60) } ?? 720 }
    private var requestDuration: TimeInterval {
        guard mode == .fixedDateTime, repeatMode == .weekdays else { return durationMinutes * 60 }
        return makeRecurrence().duration
    }
    private var safetyLimitText: String? {
        guard let maximumDuration = BearLockSafetyPolicy.maximumDuration else { return nil }
        return L10n.format("Debug safety limit: max %d min", Int(maximumDuration / 60))
    }

    private func makeRequest() -> LockCreationRequest {
        let targetID = model.lockState.selectedTarget?.id ?? UUID()
        switch mode {
        case .now: return .now(duration: durationMinutes * 60, targetSelectionID: targetID)
        case .delayed: return .delayed(delay: delayMinutes * 60, duration: durationMinutes * 60, targetSelectionID: targetID)
        case .fixedDateTime:
            if repeatMode == .none { return .fixed(startsAt: fixedStart, duration: durationMinutes * 60, targetSelectionID: targetID) }
            return .recurring(recurrence: makeRecurrence(), targetSelectionID: targetID)
        case .always: return .now(duration: 0, targetSelectionID: targetID)
        }
    }

    private func makeConfirmationDetails() -> LockConfirmationDetails {
        let isRecurring = mode == .fixedDateTime && repeatMode == .weekdays
        let start: Date
        let end: Date
        if isRecurring {
            let occurrence = makeRecurrence().nextInterval(after: Date())
            start = occurrence?.start ?? Date()
            end = occurrence?.end ?? start.addingTimeInterval(durationMinutes * 60)
        } else {
            start = mode == .now ? Date() : mode == .delayed ? Date().addingTimeInterval(delayMinutes * 60) : fixedStart
            end = start.addingTimeInterval(durationMinutes * 60)
        }
        let repeatSummary = isRecurring ? selectedWeekdays.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName() }.joined(separator: " · ") + " " + date(from: recurringStart).formatted(date: .omitted, time: .shortened) : nil
        let endSummary = mode == .now || mode == .delayed ? L10n.format("%d min after start", Int(durationMinutes)) : nil
        return LockConfirmationDetails(title: mode == .now ? "Start this lock?" : "Schedule this lock?", targetSummary: model.lockState.selectedTarget?.displayName ?? "Selected apps", startsAt: start, endsAt: end, startSummary: mode == .now ? L10n.string("After confirmation") : mode == .delayed ? L10n.format("%d min after confirmation", Int(delayMinutes)) : repeatSummary, endSummary: endSummary, isImmediate: mode == .now, isRecurring: isRecurring)
    }

    private func makeRecurrence() -> RecurrenceRule {
        let startsAt = TimeOfDay(hour: recurringStart.hour ?? 23, minute: recurringStart.minute ?? 0)
        let endDate = date(from: recurringStart).addingTimeInterval(durationMinutes * 60)
        let end = Calendar.current.dateComponents([.hour, .minute], from: endDate)
        return RecurrenceRule(weekdays: selectedWeekdays, startsAt: startsAt, endsAt: TimeOfDay(hour: end.hour ?? 0, minute: end.minute ?? 0))
    }

    private func applySafetyDefaults() {
        guard BearLockSafetyPolicy.maximumDuration != nil else { return }
        durationMinutes = min(durationMinutes, maximumDurationMinutes)
    }

    private func saveAlwaysPolicy() async {
        allowanceSaveError = nil
        let policy = DailyAllowancePolicy(isEnabled: true, targetSelection: model.lockState.selectedTarget, dailyLimitMinutes: dailyAllowanceLimitMinutes)
        let result = await model.saveDailyAllowancePolicy(policy, selection: FamilyActivitySelection())
        if !result.isSaved { allowanceSaveError = model.lastErrorMessage ?? L10n.string("Could not save settings.") }
    }

    private func date(from components: DateComponents) -> Date {
        var base = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        base.hour = components.hour; base.minute = components.minute
        return Calendar.current.date(from: base) ?? Date()
    }

    private var confirmationBinding: Binding<LockConfirmationDetails?> { Binding(get: { confirmationDetails }, set: { confirmationDetails = $0 }) }
}

extension LockConfirmationDetails: Identifiable {
    var id: String { "\(startsAt.timeIntervalSince1970)-\(endsAt.timeIntervalSince1970)-\(targetSummary)" }
}
