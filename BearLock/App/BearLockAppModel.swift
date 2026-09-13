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
    private var isRefreshing = false

    var activeLock: ActiveLock? { lockState.activeLocks(at: Date()).first }
    private let diagnostics = DiagnosticsLogger.shared

    init(
        authorizationService: AuthorizationServicing,
        targetSelectionStore: TargetSelectionStoring,
        shieldController: ShieldControlling,
        scheduleController: ScheduleControlling,
        lockStore: LockStore
    ) {
        self.authorizationService = authorizationService
        self.targetSelectionStore = targetSelectionStore
        self.shieldController = shieldController
        self.scheduleController = scheduleController
        self.lockStore = lockStore
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
                authorizationService: UITestingAuthorizationService(status: uiTestingAuthorizationStatus, deny: ProcessInfo.processInfo.arguments.contains("--ui-testing-deny-authorization")),
                targetSelectionStore: selectionStore,
                shieldController: NoopShieldController(),
                scheduleController: NoopScheduleController(),
                lockStore: lockStore
            )
        }

        return BearLockAppModel(
            authorizationService: FamilyControlsAuthorizationService(),
            targetSelectionStore: FamilyActivityTargetSelectionStore(),
            shieldController: ManagedSettingsShieldController(),
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
            UserDefaults.standard.removeObject(forKey: "hasSeenIntroduction")
            try? FileManager.default.removeItem(at: uiTestingRepositoryURL)
        }

        guard arguments.contains("--ui-testing-seeded") else {
            return
        }

        let target = LockTargetSelectionRef(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: L10n.format("%d targets", 3)
        )
        let workTarget = LockTargetSelectionRef(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            displayName: L10n.format("%d targets", 5)
        )
        let sleepTarget = LockTargetSelectionRef(
            id: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!,
            displayName: L10n.format("%d targets", 2)
        )
        let now = Date()
        let targetSelections = [workTarget, sleepTarget, target]
        let recentLockTargets = [
            RecentLockTarget(
                id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
                targetSelectionID: workTarget.id,
                lastUsedAt: now.addingTimeInterval(-3_600),
                pinnedAt: now.addingTimeInterval(-3_500)
            ),
            RecentLockTarget(
                id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
                targetSelectionID: target.id,
                lastUsedAt: now.addingTimeInterval(-600)
            ),
            RecentLockTarget(
                id: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
                targetSelectionID: sleepTarget.id,
                lastUsedAt: now.addingTimeInterval(-1_800)
            )
        ]
        let state: LockState
        if arguments.contains("--ui-testing-active-lock") {
            state = LockState(
                targetSelections: targetSelections,
                recentLockTargets: recentLockTargets,
                rules: [LockRule(
                    kind: .immediate,
                    startsAt: now.addingTimeInterval(-5 * 60),
                    duration: 120 * 60,
                    targetSelectionID: target.id
                )]
            )
        } else if arguments.contains("--ui-testing-active-recurring") {
            let start = now.addingTimeInterval(-300)
            let end = now.addingTimeInterval(3600)
            let calendar = Calendar.current
            let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases),
                startsAt: TimeOfDay(hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start)),
                endsAt: TimeOfDay(hour: calendar.component(.hour, from: end), minute: calendar.component(.minute, from: end)))
            state = LockState(targetSelections: targetSelections, recentLockTargets: recentLockTargets,
                rules: [LockRule(kind: .recurring, startsAt: start, duration: recurrence.duration,
                    recurrence: recurrence, targetSelectionID: target.id)])
        } else if arguments.contains("--ui-testing-disabled-recurring") {
            let recurrence = RecurrenceRule(
                weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                startsAt: TimeOfDay(hour: 23, minute: 0),
                endsAt: TimeOfDay(hour: 7, minute: 0)
            )
            state = LockState(
                targetSelections: targetSelections,
                recentLockTargets: recentLockTargets,
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
            state = LockState(
                targetSelections: targetSelections,
                recentLockTargets: recentLockTargets
            )
        }

        do {
            var existingState = try repository.load()
            if existingState.targetSelections.isEmpty {
                existingState.targetSelections = state.targetSelections
                existingState.recentLockTargets = state.recentLockTargets
                existingState.rules = state.rules
                try repository.save(existingState)
            }
        } catch {
            try? repository.save(state)
        }
    }

    func refresh() async {
        guard !isRefreshing, !isCreatingLock, !isUpdatingLock else { return }
        isRefreshing = true
        defer { isRefreshing = false; hasLoadedInitialState = true; refreshDiagnostics() }
        authorizationStatus = authorizationService.currentStatus()
        await synchronizeAndReconcile(isRefresh: true)
    }

    /// Persisted rules are the desired state. Failed OS registration is retried on
    /// the next refresh or rule operation; it must not prevent expiry reconciliation.
    private func synchronizeAndReconcile(isRefresh: Bool = false) async {
        do {
            lockState = try await lockStore.snapshot()
        } catch {
            recordError("Lock.load.failed", error)
            return
        }
        if isRefresh && (isCreatingLock || isUpdatingLock) { return }
        do {
            if authorizationStatus == .approved {
                try scheduleController.synchronize(lockState.rules, at: Date())
            }
        } catch {
            recordError("Schedule.synchronize.failed", error)
            lastErrorMessage = L10n.string("Your schedules are saved, but monitoring could not be updated. Reopen Bear Lock to retry.")
        }
        let shield = shieldController
        let logger = diagnostics
        do {
            lockState = try await lockStore.reconcile(
                apply: { try shield.applyShield(selections: $0) },
                record: { logger.record("Lock.reconcile", detail: $0) }
            )
        } catch {
            recordError("Lock.reconcile.failed", error)
        }
    }

    func requestAuthorization() async {
        diagnostics.record("Authorization.request.started")
        do {
            try await authorizationService.requestAuthorization()
            authorizationStatus = authorizationService.currentStatus()
            diagnostics.record("Authorization.request.succeeded", detail: authorizationStatus.diagnosticsText)
            await refresh()
        } catch {
            recordError("Authorization.request.failed", error)
            authorizationStatus = authorizationService.currentStatus()
        }
        refreshDiagnostics()
    }

    @discardableResult
    func saveSelection(_ selection: FamilyActivitySelection) async -> Bool {
        diagnostics.record("Selection.save.started")
        do {
            let state = try await lockStore.snapshot()
            if !state.activeLocks(at: Date()).isEmpty {
                throw TargetSelectionStoreError.activeLockInProgress
            }

            let ref = try targetSelectionStore.save(selection)
            let savedRef = try await lockStore.saveTargetSelection(ref)
            lockState = try await lockStore.snapshot()
            diagnostics.record("Selection.save.succeeded", detail: "\(savedRef.displayName) id=\(savedRef.id.uuidString)")
            refreshDiagnostics()
            return true
        } catch {
            recordError("Selection.save.failed", error)
        }
        refreshDiagnostics()
        return false
    }

    func saveUITestingSelection(count: Int) async {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing-target-picker"), count > 0 else {
            return
        }

        do {
            let ref = LockTargetSelectionRef(displayName: L10n.format("%d targets", count))
            _ = try await lockStore.saveTargetSelection(ref)
            lockState = try await lockStore.snapshot()
            diagnostics.record("Selection.uiTestingSave.succeeded", detail: "count=\(count)")
        } catch {
            recordError("Selection.uiTestingSave.failed", error)
        }
        refreshDiagnostics()
    }

    @discardableResult
    func createLock(_ request: LockCreationRequest) async -> Bool {
        guard !isCreatingLock, !isUpdatingLock else { return false }
        isCreatingLock = true
        defer { isCreatingLock = false; refreshDiagnostics() }
        do {
            try BearLockSafetyPolicy.validate(request)
            let rule = try await lockStore.createRule(request)
            do {
                try await lockStore.recordRecentLockTarget(targetSelectionID: rule.targetSelectionID, usedAt: Date())
            } catch {
                diagnostics.record("RecentTarget.record.failed", level: .warning, detail: error.localizedDescription)
            }
            await synchronizeAndReconcile()
            diagnostics.record("Lock.create.saved", detail: lockDetail(for: rule))
            // The rule is saved even if OS registration failed. Close the editor
            // so retrying registration cannot accidentally create another rule.
            return true
        } catch {
            recordError("Lock.create.failed", error)
            return false
        }
    }

    func deleteScheduledRule(_ rule: LockRule) async {
        guard !isCreatingLock, !isUpdatingLock else { return }
        isUpdatingLock = true
        defer { isUpdatingLock = false; refreshDiagnostics() }
        do {
            try await lockStore.deleteRule(id: rule.id)
            await synchronizeAndReconcile()
        } catch {
            recordError("Schedule.delete.failed", error)
        }
    }

    @discardableResult
    func selectRecentLockTarget(_ recentTarget: RecentLockTarget) async -> Bool {
        diagnostics.record("RecentTarget.select.started", detail: recentTarget.id.uuidString)
        do {
            let state = try await lockStore.snapshot()
            if !state.activeLocks(at: Date()).isEmpty {
                throw TargetSelectionStoreError.activeLockInProgress
            }
            guard let selection = state.targetSelections.last(where: { $0.id == recentTarget.targetSelectionID }) else {
                throw RecentLockTargetError.targetSelectionNotFound
            }

            try targetSelectionStore.activate(selection)
            _ = try await lockStore.saveTargetSelection(selection)
            lockState = try await lockStore.snapshot()
            diagnostics.record("RecentTarget.select.succeeded", detail: recentTarget.id.uuidString)
            refreshDiagnostics()
            return true
        } catch {
            recordError("RecentTarget.select.failed", error)
            refreshDiagnostics()
            return false
        }
    }

    func setRecentLockTargetPinned(_ recentTarget: RecentLockTarget, pinned: Bool) async {
        diagnostics.record("RecentTarget.pin.started", detail: recentTarget.id.uuidString)
        do {
            try await lockStore.setRecentLockTargetPinned(id: recentTarget.id, pinned: pinned, at: Date())
            lockState = try await lockStore.snapshot()
            diagnostics.record("RecentTarget.pin.succeeded", detail: pinned ? "pinned" : "unpinned")
        } catch {
            recordError("RecentTarget.pin.failed", error)
        }
        refreshDiagnostics()
    }

    func deleteRecentLockTarget(_ recentTarget: RecentLockTarget) async {
        diagnostics.record("RecentTarget.delete.started", detail: recentTarget.id.uuidString)
        do {
            try await lockStore.deleteRecentLockTarget(id: recentTarget.id)
            lockState = try await lockStore.snapshot()
            diagnostics.record("RecentTarget.delete.succeeded", detail: recentTarget.id.uuidString)
        } catch {
            recordError("RecentTarget.delete.failed", error)
        }
        refreshDiagnostics()
    }

    @discardableResult
    func updateScheduledRule(_ original: LockRule, startsAt: Date, duration: TimeInterval) async -> Bool {
        var replacement = original
        replacement.startsAt = startsAt
        replacement.duration = duration
        return await saveRule(replacement)
    }

    @discardableResult
    func updateRecurringRule(_ original: LockRule, recurrence: RecurrenceRule, enabled: Bool) async -> Bool {
        var replacement = original
        replacement.recurrence = recurrence
        replacement.duration = recurrence.duration
        replacement.status = enabled ? .scheduled : .disabled
        return await saveRule(replacement)
    }

    private func saveRule(_ replacement: LockRule) async -> Bool {
        guard !isCreatingLock, !isUpdatingLock else { return false }
        isUpdatingLock = true
        defer { isUpdatingLock = false; refreshDiagnostics() }
        do {
            try BearLockSafetyPolicy.validateDuration(replacement.duration)
            try await lockStore.replaceRule(replacement)
            await synchronizeAndReconcile()
            return true
        } catch {
            recordError("Schedule.update.failed", error)
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
            activeLockStatus: activeLock.map { L10n.format("Active until %@", $0.endsAt.formatted(date: .omitted, time: .shortened)) } ?? L10n.string("None"),
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
        lastErrorMessage = userFacingMessage(for: error)
        diagnostics.record(name, level: .error, detail: diagnosticDetail(for: error))
    }

    private func userFacingMessage(for error: Error) -> String {
        if let validationError = error as? LockValidationError {
            switch validationError {
            case .nonPositiveDuration:
                return L10n.string("Choose a lock duration longer than zero.")
            case .startDateInPast:
                return L10n.string("Choose a start time in the future.")
            case .emptyWeekdays:
                return L10n.string("Choose at least one weekday.")
            case .overlappingLock:
                return L10n.string("This overlaps an existing lock. Edit the schedule or choose a different time.")
            case .activeLockIsImmutable:
                return L10n.string("This lock is already active and cannot be changed.")
            case .ruleAlreadyStarted:
                return L10n.string("This lock has already started and cannot be changed.")
            case .ruleNotFound:
                return L10n.string("This schedule is no longer available.")
            case .notRecurringRule:
                return L10n.string("Only repeating locks can be changed here.")
            }
        }

        if let recentTargetError = error as? RecentLockTargetError {
            switch recentTargetError {
            case .targetSelectionNotFound, .recentTargetNotFound:
                return L10n.string("This saved target is no longer available.")
            case .pinnedTargetLimitReached:
                return L10n.string("You can pin up to three targets.")
            }
        }

        return error.localizedDescription
    }

    private func diagnosticDetail(for error: Error) -> String {
        if let validationError = error as? LockValidationError {
            return "LockValidationError.\(validationError)"
        }
        return error.localizedDescription
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
