#if DEBUG
import BearLockCore
import Foundation
import SwiftUI

enum ScreenshotScreen: String, CaseIterable {
    case setup
    case home
    case composeNow
    case composeDelayed
    case composeDate
    case composeRepeat
    case composeAlways
    case allowanceTargetSelection
    case allowanceLocked
    case allowanceTemporary
    case allowanceReturned
    case allowanceExhausted
    case allowanceNextDay
    case allowancePending
    case allowanceStopped
    case confirmation
    case scheduledList
    case activeLock
    case wakeOptions
    case wakeResult
    case scheduledEditor
    case recurringEditor
    case settings
    case support
#if DEBUG
    case diagnostics
#endif

    static func current(from arguments: [String] = ProcessInfo.processInfo.arguments) -> ScreenshotScreen? {
        guard let index = arguments.firstIndex(of: "--screenshot"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return ScreenshotScreen(rawValue: arguments[index + 1])
    }
}

@MainActor
struct ScreenshotHostView: View {
    let screen: ScreenshotScreen
    @StateObject private var model: BearLockAppModel
    @State private var wakeTarget: ActiveLock?

    init(screen: ScreenshotScreen) {
        self.screen = screen
        _model = StateObject(wrappedValue: BearLockAppModel.screenshot(for: screen))
    }

    var body: some View {
        NavigationStack {
            content
                .background(AppTheme.background.ignoresSafeArea())
        }
        .environmentObject(model)
        .task {
            await model.refresh()
            if screen == .wakeOptions {
                wakeTarget = model.activeLock
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .setup:
            SetupView()
        case .home:
            HomeView(onWake: { _ in })
        case .composeNow:
            ScrollView {
                screenshotStack(title: "Start now") {
                    LockComposerView(mode: .constant(.now))
                }
            }
            .navigationTitle("Start now")
        case .composeDelayed:
            ScrollView {
                screenshotStack(title: "Start later") {
                    LockComposerView(mode: .constant(.delayed))
                }
            }
            .navigationTitle("Start later")
        case .composeDate:
            ScrollView {
                screenshotStack(title: "Date & Time") {
                    LockComposerView(mode: .constant(.fixedDateTime))
                }
            }
            .navigationTitle("Date & Time")
        case .composeRepeat:
            ScrollView {
                screenshotStack(title: "Date & Time") {
                    LockComposerView(mode: .constant(.fixedDateTime), startsWithWeekdays: true)
                }
            }
            .navigationTitle("Date & Time")
        case .composeAlways:
            HomeView(initialComposerMode: .always, onWake: { _ in })
        case .allowanceTargetSelection:
            HomeView(initialComposerMode: .always, onWake: { _ in })
        case .allowanceLocked, .allowanceTemporary, .allowanceReturned, .allowanceExhausted, .allowanceNextDay, .allowancePending, .allowanceStopped:
            ScrollView {
                ScheduledLockListView()
                    .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        case .confirmation:
            LockConfirmationSheet(
                details: ScreenshotFixtures.confirmationDetails,
                isSubmitting: false,
                onCancel: {},
                onConfirm: {}
            )
            .background(AppTheme.background.ignoresSafeArea())
        case .scheduledList:
            ScrollView {
                screenshotStack(title: "Scheduled") {
                    ScheduledLockListView()
                }
            }
            .navigationTitle("Schedules")
        case .activeLock:
            HomeView(onWake: { _ in })
        case .wakeOptions:
            Color.clear
                .wakeOptionsDialog(target: $wakeTarget)
        case .wakeResult:
            WakeResultView()
        case .scheduledEditor:
            ScheduledLockEditorView(
                rule: ScreenshotFixtures.delayedRule,
                isSaving: false,
                onCancel: {},
                onSave: { _, _ in }
            )
        case .recurringEditor:
            RecurringRuleEditorView(
                rule: ScreenshotFixtures.recurringRule,
                isSaving: false,
                onCancel: {},
                onSave: { _, _ in }
            )
        case .settings:
            SettingsView()
        case .support:
            SupportView()
#if DEBUG
        case .diagnostics:
            DebugDiagnosticsView()
#endif
        }
    }

    private func screenshotStack<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(AppTheme.steel)
                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .foregroundStyle(AppTheme.navy)
            }
            content()
        }
        .padding(20)
    }
}

private enum ScreenshotFixtures {
    static let targetID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let workTargetID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    static let sleepTargetID = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!

    static let target = LockTargetSelectionRef(
        id: targetID,
        displayName: L10n.format("%d targets", 3),
        tokenData: Data([1])
    )

    static let workTarget = LockTargetSelectionRef(
        id: workTargetID,
        displayName: L10n.format("%d targets", 5)
    )

    static let sleepTarget = LockTargetSelectionRef(
        id: sleepTargetID,
        displayName: L10n.format("%d targets", 2)
    )

    static var recentLockTargets: [RecentLockTarget] {
        let now = Date()
        return [
            RecentLockTarget(
                id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
                targetSelectionID: workTargetID,
                lastUsedAt: now.addingTimeInterval(-3_600),
                pinnedAt: now.addingTimeInterval(-3_500)
            ),
            RecentLockTarget(
                id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
                targetSelectionID: targetID,
                lastUsedAt: now.addingTimeInterval(-600)
            ),
            RecentLockTarget(
                id: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
                targetSelectionID: sleepTargetID,
                lastUsedAt: now.addingTimeInterval(-1_800)
            )
        ]
    }

    static var activeLock: ActiveLock {
        let now = Date()
        return ActiveLock(
            startedAt: now.addingTimeInterval(-26 * 60),
            endsAt: now.addingTimeInterval(94 * 60),
            targetSelectionID: targetID
        )
    }

    static var delayedRule: LockRule {
        LockRule(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            kind: .delayed,
            startsAt: Date().addingTimeInterval(30 * 60),
            duration: 120 * 60,
            targetSelectionID: targetID
        )
    }

    static var fixedRule: LockRule {
        LockRule(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            kind: .fixedDateTime,
            startsAt: Date().addingTimeInterval(7 * 60 * 60),
            duration: 150 * 60,
            targetSelectionID: targetID
        )
    }

    static var recurringRule: LockRule {
        let recurrence = RecurrenceRule(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            startsAt: TimeOfDay(hour: 23, minute: 0),
            endsAt: TimeOfDay(hour: 7, minute: 0)
        )
        return LockRule(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            recurrence: recurrence,
            targetSelectionID: targetID
        )
    }

    static var disabledRecurringRule: LockRule {
        var rule = recurringRule
        rule.id = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        rule.status = .disabled
        return rule
    }

    static var state: LockState {
        LockState(
            targetSelections: [workTarget, sleepTarget, target],
            recentLockTargets: recentLockTargets,
            rules: [delayedRule, fixedRule, recurringRule, disabledRecurringRule], selectedTargetID: targetID
        )
    }

    static func allowanceState(
        consumedMinutes: Int,
        usageDayStart: Date,
        grant: DailyAllowanceGrant? = nil,
        isEnabled: Bool = true,
        pendingPolicy: ScheduledDailyAllowancePolicy? = nil
    ) -> LockState {
        var state = LockState(targetSelections: [target], selectedTargetID: targetID)
        state.dailyAllowance = DailyAllowanceState(
            currentPolicy: DailyAllowancePolicy(
                isEnabled: isEnabled,
                targetSelection: target,
                dailyLimitMinutes: 60
            ),
            pendingPolicy: pendingPolicy,
            usageDayStart: usageDayStart,
            consumedMinutes: consumedMinutes,
            grant: grant
        )
        return state
    }

    static var activeState: LockState {
        LockState(
            targetSelections: [workTarget, sleepTarget, target],
            recentLockTargets: recentLockTargets,
            rules: [recurringRule, LockRule(kind: .immediate, startsAt: activeLock.startedAt, duration: activeLock.endsAt.timeIntervalSince(activeLock.startedAt), targetSelectionID: targetID)], selectedTargetID: targetID
        )
    }

    static var confirmationDetails: LockConfirmationDetails {
        let start = Date().addingTimeInterval(30 * 60)
        return LockConfirmationDetails(
            title: "Schedule Bear's sleep.",
            targetSummary: target.displayName,
            startsAt: start,
            endsAt: start.addingTimeInterval(120 * 60),
            isImmediate: false
        )
    }
}

private struct StaticLockRepository: LockRepository {
    let state: LockState

    func load() throws -> LockState {
        state
    }

    func save(_ state: LockState) throws {}
}

private extension BearLockAppModel {
    static func screenshot(for screen: ScreenshotScreen) -> BearLockAppModel {
        let state: LockState
        let status: AuthorizationState

        switch screen {
        case .setup:
            state = LockState()
            status = .unknown
        case .allowanceTargetSelection:
            state = LockState()
            status = .approved
        case .activeLock, .wakeOptions:
            state = ScreenshotFixtures.activeState
            status = .approved
        case .allowanceLocked:
            let now = Date()
            state = ScreenshotFixtures.allowanceState(consumedMinutes: 20, usageDayStart: Calendar.current.startOfDay(for: now))
            status = .approved
        case .allowanceTemporary:
            let now = Date()
            let grant = DailyAllowanceGrant(id: UUID(), durationMinutes: 5, expiresAt: now.addingTimeInterval(4 * 60))
            state = ScreenshotFixtures.allowanceState(consumedMinutes: 5, usageDayStart: Calendar.current.startOfDay(for: now), grant: grant)
            status = .approved
        case .allowanceReturned:
            let now = Date()
            state = ScreenshotFixtures.allowanceState(consumedMinutes: 3, usageDayStart: Calendar.current.startOfDay(for: now))
            status = .approved
        case .allowanceExhausted:
            let now = Date()
            state = ScreenshotFixtures.allowanceState(consumedMinutes: 60, usageDayStart: Calendar.current.startOfDay(for: now))
            status = .approved
        case .allowanceNextDay:
            let now = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now)) ?? now
            state = ScreenshotFixtures.allowanceState(consumedMinutes: 60, usageDayStart: yesterday)
            status = .approved
        case .allowancePending:
            let now = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
            let pending = DailyAllowancePolicy(isEnabled: true, targetSelection: ScreenshotFixtures.target, dailyLimitMinutes: 30)
            state = ScreenshotFixtures.allowanceState(
                consumedMinutes: 20,
                usageDayStart: Calendar.current.startOfDay(for: now),
                pendingPolicy: ScheduledDailyAllowancePolicy(policy: pending, effectiveAt: tomorrow)
            )
            status = .approved
        case .allowanceStopped:
            let now = Date()
            state = ScreenshotFixtures.allowanceState(
                consumedMinutes: 20,
                usageDayStart: Calendar.current.startOfDay(for: now),
                isEnabled: false
            )
            status = .approved
        default:
            state = ScreenshotFixtures.state
            status = .approved
        }

        let lockStore = LockStore(repository: StaticLockRepository(state: state))

        return BearLockAppModel(
            authorizationService: PreviewAuthorizationService(status: status),
            targetSelectionCodec: PreviewTargetSelectionCodec(usesSummaryFixtures: true),
            shieldController: NoopShieldController(),
            scheduleController: NoopScheduleController(),
            lockStore: lockStore
        )
    }
}
#endif
