import Foundation
import BearLockCore
import FamilyControls

@MainActor
final class BearLockAppModel: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationState = .unknown
    @Published private(set) var lockState = LockState()
    @Published private(set) var hasLoadedInitialState = false
    @Published private(set) var isCreatingLock = false
    @Published private(set) var isUpdatingLock = false
    @Published var lastErrorMessage: String?
    @Published private(set) var diagnosticsSnapshot = DiagnosticsSnapshot.empty
    @Published private(set) var diagnosticsWritable = false

    let authorizationService: AuthorizationServicing
    let targetSelectionStore: TargetSelectionStoring
    let shieldController: ShieldControlling
    let scheduleController: ScheduleControlling
    private let lockStore: LockStore
    private let planner: LockPlanner
    private let diagnostics = DiagnosticsLogger.shared

    init(
        authorizationService: AuthorizationServicing,
        targetSelectionStore: TargetSelectionStoring,
        shieldController: ShieldControlling,
        scheduleController: ScheduleControlling,
        lockStore: LockStore,
        planner: LockPlanner = LockPlanner()
    ) {
        self.authorizationService = authorizationService
        self.targetSelectionStore = targetSelectionStore
        self.shieldController = shieldController
        self.scheduleController = scheduleController
        self.lockStore = lockStore
        self.planner = planner
        diagnostics.record("AppModel.initialized")
    }

    static func live() -> BearLockAppModel {
        let repository: JSONFileLockRepository
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            repository = JSONFileLockRepository(fileURL: uiTestingRepositoryURL)
            seedUITestingStateIfNeeded(repository: repository)
        } else {
            repository = JSONFileLockRepository(fileURL: AppGroup.lockStateURL)
        }

        let lockStore: LockStore
        do {
            lockStore = try LockStore(repository: repository)
        } catch {
            fatalError("Failed to initialize Bear Lock store: \(error)")
        }

        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let selectionStore = PreviewTargetSelectionStore()
            return BearLockAppModel(
                authorizationService: PreviewAuthorizationService(status: uiTestingAuthorizationStatus),
                targetSelectionStore: selectionStore,
                shieldController: NoopShieldController(),
                scheduleController: NoopScheduleController(),
                lockStore: lockStore
            )
        }

        return BearLockAppModel(
            authorizationService: FamilyControlsAuthorizationService(),
            targetSelectionStore: FamilyActivityTargetSelectionStore(),
            shieldController: ManagedSettingsShieldController(selectionStore: FamilyActivityTargetSelectionStore()),
            scheduleController: DeviceActivityScheduleController(),
            lockStore: lockStore
        )
    }

    private static var uiTestingRepositoryURL: URL {
        FileManager.default.temporaryDirectory.appending(path: "bearlock-ui-test-state.json")
    }

    private static var uiTestingAuthorizationStatus: AuthorizationState {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-approved") ? .approved : .unknown
    }

    private static func seedUITestingStateIfNeeded(repository: JSONFileLockRepository) {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--reset-ui-testing-state") {
            try? FileManager.default.removeItem(at: uiTestingRepositoryURL)
        }

        guard arguments.contains("--ui-testing-seeded") else {
            return
        }

        let target = LockTargetSelectionRef(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "SNS, Video, Games"
        )
        let state: LockState
        if arguments.contains("--ui-testing-active-lock") {
            let now = Date()
            state = LockState(
                targetSelections: [target],
                activeLock: ActiveLock(
                    sourceRuleID: nil,
                    startedAt: now.addingTimeInterval(-5 * 60),
                    endsAt: now.addingTimeInterval(115 * 60),
                    targetSelectionID: target.id
                )
            )
        } else if arguments.contains("--ui-testing-disabled-recurring") {
            let recurrence = RecurrenceRule(
                weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0)
            )
            state = LockState(
                targetSelections: [target],
                rules: [
                    LockRule(
                        kind: .recurring,
                        startsAt: recurrence.nextInterval(after: Date())?.start ?? Date().addingTimeInterval(24 * 60 * 60),
                        duration: recurrence.duration,
                        recurrence: recurrence,
                        targetSelectionID: target.id,
                        status: .disabled
                    )
                ]
            )
        } else {
            state = LockState(targetSelections: [target])
        }

        do {
            var existingState = try repository.load()
            if existingState.targetSelections.isEmpty {
                existingState.targetSelections = state.targetSelections
                existingState.rules = state.rules
                existingState.activeLock = state.activeLock
                existingState.completedLocks = state.completedLocks
                try repository.save(existingState)
            }
        } catch {
            try? repository.save(state)
        }
    }

    func refresh() async {
        diagnostics.record("App.refresh.started")
        let now = Date()
        authorizationStatus = authorizationService.currentStatus()
        lockState = await lockStore.snapshot()

        if let completed = try? await lockStore.completeActiveLock(at: now) {
            shieldController.clearShield(for: completed)
            diagnostics.record("ActiveLock.completed", detail: completed.id.uuidString)
            lockState = await lockStore.snapshot()
        }

        if let completedRules = try? await lockStore.completeExpiredOneShotRules(at: now), !completedRules.isEmpty {
            diagnostics.record("Rules.completedExpiredOneShot", detail: "\(completedRules.count)")
        }
        lockState = await lockStore.snapshot()

        if let active = lockState.activeLock, active.isActive(at: now) {
            shieldController.applyShield(for: active)
            diagnostics.record("ActiveLock.refreshAppliedShield", detail: active.id.uuidString)
        } else if lockState.activeLock == nil,
                  let rule = planner.scheduledRuleContaining(now, in: lockState.rules) {
            let active = planner.activeLock(from: rule, intervalStart: rule.startsAt)
            do {
                try await lockStore.activate(active)
                shieldController.applyShield(for: active)
                lockState = await lockStore.snapshot()
                diagnostics.record("ActiveLock.autoActivated", detail: rule.kind.rawValue)
            } catch {
                recordError("ActiveLock.autoActivate.failed", error)
            }
        }
        refreshDiagnostics()
        hasLoadedInitialState = true
    }

    func requestAuthorization() async {
        diagnostics.record("Authorization.request.started")
        do {
            try await authorizationService.requestAuthorization()
            authorizationStatus = authorizationService.currentStatus()
            diagnostics.record("Authorization.request.succeeded", detail: authorizationStatus.diagnosticsText)
        } catch {
            recordError("Authorization.request.failed", error)
            authorizationStatus = authorizationService.currentStatus()
        }
        refreshDiagnostics()
    }

    func saveSelection(_ selection: FamilyActivitySelection) async {
        diagnostics.record("Selection.save.started")
        do {
            let state = await lockStore.snapshot()
            if let active = state.activeLock, active.isActive(at: Date()) {
                throw TargetSelectionStoreError.activeLockInProgress
            }

            let ref = try targetSelectionStore.save(selection)
            try await lockStore.saveTargetSelection(ref)
            lockState = await lockStore.snapshot()
            diagnostics.record("Selection.save.succeeded", detail: "\(ref.displayName) id=\(ref.id.uuidString)")
        } catch {
            recordError("Selection.save.failed", error)
        }
        refreshDiagnostics()
    }

    @discardableResult
    func createLock(_ request: LockCreationRequest) async -> Bool {
        isCreatingLock = true
        defer { isCreatingLock = false }
        diagnostics.record("Lock.create.started", detail: request.diagnosticsText)

        do {
            try BearLockSafetyPolicy.validate(request)

            let now = Date()
            let state = await lockStore.snapshot()
            let rule = try planner.makeRule(
                from: request,
                now: now,
                existingRules: state.rules,
                activeLock: state.activeLock
            )

            switch rule.kind {
            case .immediate:
                diagnostics.record("Schedule.create.started", detail: rule.kind.rawValue)
                try await lockStore.addRule(rule)
                do {
                    try scheduleController.schedule(rule)
                } catch {
                    try? await lockStore.deleteRule(id: rule.id, now: now)
                    throw error
                }
                let active = planner.activeLock(from: rule, intervalStart: now)
                do {
                    try await lockStore.activate(active)
                    shieldController.applyShield(for: active)
                    diagnostics.record("Lock.create.succeeded", detail: lockDetail(for: rule, active: active))
                } catch {
                    try? scheduleController.cancel(rule)
                    try? await lockStore.deleteRule(id: rule.id, now: now)
                    try? await lockStore.clearActiveLock(id: active.id)
                    throw error
                }
            case .delayed, .fixedDateTime, .recurring:
                diagnostics.record("Schedule.create.started", detail: rule.kind.rawValue)
                try scheduleController.schedule(rule)
                do {
                    try await lockStore.addRule(rule)
                    diagnostics.record("Lock.create.succeeded", detail: lockDetail(for: rule))
                } catch {
                    try? scheduleController.cancel(rule)
                    throw error
                }
            }

            lockState = await lockStore.snapshot()
            refreshDiagnostics()
            return true
        } catch {
            recordError("Lock.create.failed", error)
            refreshDiagnostics()
            return false
        }
    }

    func deleteScheduledRule(_ rule: LockRule) async {
        diagnostics.record("Schedule.delete.started", detail: rule.kind.rawValue)
        do {
            try await lockStore.deleteRule(id: rule.id, now: Date())
            try scheduleController.cancel(rule)
            lockState = await lockStore.snapshot()
            diagnostics.record("Schedule.delete.succeeded", detail: rule.kind.rawValue)
        } catch {
            recordError("Schedule.delete.failed", error)
        }
        refreshDiagnostics()
    }

    @discardableResult
    func updateScheduledRule(_ original: LockRule, startsAt: Date, duration: TimeInterval) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }
        diagnostics.record("Schedule.update.started", detail: original.kind.rawValue)

        do {
            try BearLockSafetyPolicy.validateDuration(duration)

            let now = Date()
            let state = await lockStore.snapshot()
            var replacement = original
            replacement.startsAt = startsAt
            replacement.duration = duration

            let validated = try planner.validateScheduledReplacement(
                replacement,
                replacing: original,
                now: now,
                existingRules: state.rules,
                activeLock: state.activeLock
            )

            do {
                try scheduleController.schedule(validated)
                try await lockStore.replaceRule(validated, now: now)
            } catch {
                try? scheduleController.schedule(original)
                throw error
            }

            lockState = await lockStore.snapshot()
            diagnostics.record("Schedule.update.succeeded", detail: validated.kind.rawValue)
            refreshDiagnostics()
            return true
        } catch {
            recordError("Schedule.update.failed", error)
            refreshDiagnostics()
            return false
        }
    }

    @discardableResult
    func updateRecurringRule(_ original: LockRule, recurrence: RecurrenceRule) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }
        diagnostics.record("Recurring.update.started")

        do {
            try BearLockSafetyPolicy.validateDuration(recurrence.duration)

            let now = Date()
            let state = await lockStore.snapshot()
            var replacement = original
            replacement.recurrence = recurrence

            let validated = try planner.validateRecurringReplacement(
                replacement,
                replacing: original,
                now: now,
                existingRules: state.rules,
                activeLock: state.activeLock
            )

            do {
                if validated.status == .scheduled {
                    try scheduleController.schedule(validated)
                }
                try await lockStore.replaceRule(validated, now: now)
            } catch {
                try? scheduleController.schedule(original)
                throw error
            }

            lockState = await lockStore.snapshot()
            diagnostics.record("Recurring.update.succeeded")
            refreshDiagnostics()
            return true
        } catch {
            recordError("Recurring.update.failed", error)
            refreshDiagnostics()
            return false
        }
    }

    @discardableResult
    func setRecurringRule(_ rule: LockRule, enabled: Bool) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }
        diagnostics.record("Recurring.setEnabled.started", detail: enabled ? "enabled" : "disabled")

        do {
            let now = Date()
            let updated = try planner.recurringRule(rule, enabled: enabled, now: now)

            do {
                if enabled {
                    try scheduleController.schedule(updated)
                } else {
                    try scheduleController.cancel(updated)
                }
                try await lockStore.replaceRule(updated, now: now)
            } catch {
                if rule.status == .scheduled {
                    try? scheduleController.schedule(rule)
                }
                throw error
            }

            lockState = await lockStore.snapshot()
            diagnostics.record("Recurring.setEnabled.succeeded", detail: enabled ? "enabled" : "disabled")
            refreshDiagnostics()
            return true
        } catch {
            recordError("Recurring.setEnabled.failed", error)
            refreshDiagnostics()
            return false
        }
    }

    func refreshDiagnostics() {
        diagnosticsSnapshot = diagnostics.snapshot()
        diagnosticsWritable = diagnostics.isWritable()
    }

    func clearDiagnostics() {
        diagnostics.clear()
        refreshDiagnostics()
    }

    var diagnosticsSummary: DiagnosticsSummary {
        DiagnosticsSummary(
            authorizationStatus: authorizationStatus.diagnosticsText,
            targetSelectionCount: latestTargetSelectionCount,
            scheduledRuleCount: lockState.rules.filter { $0.status == .scheduled }.count,
            recurringRuleCount: lockState.rules.filter { $0.kind == .recurring }.count,
            activeLockStatus: lockState.activeLock.map { L10n.format("Active until %@", $0.endsAt.formatted(date: .omitted, time: .shortened)) } ?? L10n.string("None"),
            lastError: lastErrorMessage ?? L10n.string("None"),
            lastWarning: diagnosticsSnapshot.lastEvent(level: .warning)?.summary ?? L10n.string("None"),
            lastSelectionEvent: diagnosticsSnapshot.lastEvent(named: "Selection.")?.summary ?? L10n.string("None"),
            lastLockEvent: diagnosticsSnapshot.lastEvent(named: "Lock.")?.summary ?? L10n.string("None"),
            lastDeviceActivityEvent: diagnosticsSnapshot.lastEvent(named: "DeviceActivity.")?.summary ?? L10n.string("None"),
            lastShieldEvent: diagnosticsSnapshot.lastEvent(named: "Shield.")?.summary ?? L10n.string("None"),
            lastShieldConfigurationEvent: diagnosticsSnapshot.lastEvent(named: "ShieldConfiguration.")?.summary ?? L10n.string("None"),
            safetyPolicy: BearLockSafetyPolicy.diagnosticsText,
            appGroupPath: AppGroup.containerURL.path,
            diagnosticsWritable: diagnosticsWritable,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "Unknown",
            appVersion: Self.appVersion
        )
    }

    private func recordError(_ name: String, _ error: Error) {
        lastErrorMessage = error.localizedDescription
        diagnostics.record(name, level: .error, detail: error.localizedDescription)
    }

    private func lockDetail(for rule: LockRule, active: ActiveLock? = nil) -> String {
        let activeID = active.map { " active=\($0.id.uuidString)" } ?? ""
        return "\(rule.kind.rawValue) rule=\(rule.id.uuidString) start=\(rule.startsAt.ISO8601Format()) end=\(rule.endsAt.ISO8601Format())\(activeID)"
    }

    private var latestTargetSelectionCount: Int {
        guard let tokenData = lockState.targetSelections.last?.tokenData,
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: tokenData)
        else {
            return lockState.targetSelections.isEmpty ? 0 : 1
        }

        return selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

private extension AuthorizationState {
    var diagnosticsText: String {
        switch self {
        case .unknown:
            return L10n.string("Unknown")
        case .approved:
            return L10n.string("Approved")
        case .denied:
            return L10n.string("Denied")
        }
    }
}

private extension LockCreationRequest {
    var diagnosticsText: String {
        switch self {
        case .now:
            return "now"
        case .delayed:
            return "delayed"
        case .fixed:
            return "fixedDateTime"
        case .recurring:
            return "recurring"
        }
    }
}
