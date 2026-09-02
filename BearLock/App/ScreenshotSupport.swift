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
    case confirmation
    case scheduledList
    case activeLock
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
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .setup:
            SetupView()
        case .home:
            HomeView()
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
                screenshotStack(title: "Repeat") {
                    LockComposerView(mode: .constant(.recurring))
                }
            }
            .navigationTitle("Repeat")
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
            ScrollView {
                VStack(spacing: 20) {
                    ActiveLockView(activeLock: ScreenshotFixtures.activeLock)
                    Text("During a lock, you cannot shorten it, delete it, or reduce blocked apps.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.navy.opacity(0.62))
                }
                .padding(20)
            }
            .navigationTitle("Bear is sleeping")
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
                onSave: { _ in },
                onSetEnabled: { _ in }
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

    static let target = LockTargetSelectionRef(
        id: targetID,
        displayName: "SNS, Video, Games"
    )

    static var activeLock: ActiveLock {
        let now = Date()
        return ActiveLock(
            sourceRuleID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
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
            kind: .recurring,
            startsAt: recurrence.nextInterval(after: Date())?.start ?? Date().addingTimeInterval(24 * 60 * 60),
            duration: recurrence.duration,
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
            targetSelections: [target],
            rules: [delayedRule, fixedRule, recurringRule, disabledRecurringRule],
            activeLock: nil
        )
    }

    static var activeState: LockState {
        LockState(
            targetSelections: [target],
            rules: [recurringRule],
            activeLock: activeLock
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
        case .activeLock:
            state = ScreenshotFixtures.activeState
            status = .approved
        default:
            state = ScreenshotFixtures.state
            status = .approved
        }

        let lockStore: LockStore
        do {
            lockStore = try LockStore(repository: StaticLockRepository(state: state))
        } catch {
            fatalError("Failed to initialize screenshot store: \(error)")
        }

        return BearLockAppModel(
            authorizationService: PreviewAuthorizationService(status: status),
            targetSelectionStore: PreviewTargetSelectionStore(),
            shieldController: NoopShieldController(),
            scheduleController: NoopScheduleController(),
            lockStore: lockStore
        )
    }
}
