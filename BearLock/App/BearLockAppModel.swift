import Foundation
import BearLockCore
import FamilyControls

@MainActor
final class BearLockAppModel: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationState = .unknown
    @Published private(set) var lockState = LockState()
    enum ReadStatus { case loading, loaded, failed }
    @Published private(set) var readStatus: ReadStatus = .loading
    var hasLoadedInitialState: Bool { readStatus == .loaded }
    @Published private(set) var monitoringUpdateFailed = false
    @Published private(set) var isCreatingLock = false
    @Published private(set) var isUpdatingLock = false
    @Published private(set) var isHandlingWake = false
    @Published private(set) var wakeCompletionID: UUID?
    @Published var lastErrorMessage: String?
    @Published private(set) var diagnosticsSnapshot = DiagnosticsSnapshot.empty
    @Published private(set) var diagnosticsWritable = false

    let authorizationService: AuthorizationServicing
    let targetSelectionCodec: TargetSelectionCoding
    let shieldController: ShieldControlling
    let scheduleController: ScheduleControlling
    private let lockStore: LockStore
    @Published private(set) var isRefreshing = false

    var activeLock: ActiveLock? { lockState.activeLockForDisplay(at: Date()) }
    private let diagnostics = DiagnosticsLogger.shared

    init(
        authorizationService: AuthorizationServicing,
        targetSelectionCodec: TargetSelectionCoding,
        shieldController: ShieldControlling,
        scheduleController: ScheduleControlling,
        lockStore: LockStore
    ) {
        self.authorizationService = authorizationService
        self.targetSelectionCodec = targetSelectionCodec
        self.shieldController = shieldController
        self.scheduleController = scheduleController
        self.lockStore = lockStore
        diagnostics.record("AppModel.initialized")
    }

    static func live() -> BearLockAppModel {
        #if DEBUG
        let repository: JSONFileLockRepository
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            repository = JSONFileLockRepository(fileURL: uiTestingRepositoryURL)
            seedUITestingStateIfNeeded(repository: repository)
        } else {
            repository = JSONFileLockRepository(fileURL: AppGroup.lockStateURL)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let selectionStore = PreviewTargetSelectionCodec(usesSummaryFixtures: ProcessInfo.processInfo.arguments.contains("--ui-testing-target-summary"))
            return BearLockAppModel(
                authorizationService: UITestingAuthorizationService(status: uiTestingAuthorizationStatus, deny: ProcessInfo.processInfo.arguments.contains("--ui-testing-deny-authorization")),
                targetSelectionCodec: selectionStore,
                shieldController: NoopShieldController(),
                scheduleController: UITestingScheduleController(),
                lockStore: LockStore(repository: UITestingLockRepository(base: repository))
            )
        }
        #else
        let repository = JSONFileLockRepository(fileURL: AppGroup.lockStateURL)
        #endif

        return BearLockAppModel(
            authorizationService: FamilyControlsAuthorizationService(),
            targetSelectionCodec: FamilyActivityTargetSelectionCodec(),
            shieldController: ManagedSettingsShieldController(),
            scheduleController: DeviceActivityScheduleController(),
            lockStore: LockStore(repository: repository)
        )
    }

    #if DEBUG
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
        var state: LockState
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
            let end = arguments.contains("--ui-testing-all-day-recurring") ? start : now.addingTimeInterval(3600)
            let calendar = Calendar.current
            let recurrence = RecurrenceRule(weekdays: Set(Weekday.allCases),
                startsAt: TimeOfDay(hour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start)),
                endsAt: TimeOfDay(hour: calendar.component(.hour, from: end), minute: calendar.component(.minute, from: end)))
            state = LockState(targetSelections: targetSelections, recentLockTargets: recentLockTargets,
                rules: [LockRule(
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

        state.selectedTargetID = target.id
        do {
            var existingState = try repository.load()
            if existingState.targetSelections.isEmpty {
                existingState.targetSelections = state.targetSelections
                existingState.recentLockTargets = state.recentLockTargets
                existingState.rules = state.rules
                existingState.selectedTargetID = state.selectedTargetID
                try repository.save(existingState)
            }
        } catch {
            try? repository.save(state)
        }
    }
    #endif

    func refresh() async {
        guard !isRefreshing, !isCreatingLock, !isUpdatingLock, !isHandlingWake else { return }
        isRefreshing = true
        defer { isRefreshing = false; refreshDiagnostics() }
        authorizationStatus = authorizationService.currentStatus()
        await synchronizeAndReconcile(isRefresh: true)
    }

    /// Persisted rules are the desired state. Failed OS registration is retried on
    /// the next refresh or rule operation; it must not prevent expiry reconciliation.
    private func synchronizeAndReconcile(isRefresh: Bool = false) async {
        do {
            lockState = try await lockStore.snapshot()
            readStatus = .loaded
        } catch {
            readStatus = .failed
            recordError("Lock.load.failed", error, presentAlert: false)
            return
        }
        if isRefresh && (isCreatingLock || isUpdatingLock || isHandlingWake) { return }
        do {
            if authorizationStatus == .approved {
                let schedule = scheduleController
                try await lockStore.synchronizeMonitoring { try schedule.synchronize($0, at: $1) }
                monitoringUpdateFailed = false
            }
        } catch {
            monitoringUpdateFailed = true
            recordError("Schedule.synchronize.failed", error, presentAlert: false)
        }
        do {
            let now = Date()
            try shieldController.reconcile(state: lockState, at: now)
            diagnostics.record("Lock.reconcile", detail: "now=\(now.ISO8601Format()) stores=\(try lockState.shieldSlotDecisions(at: now).map(\.storeName))")
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
            let ref = try targetSelectionCodec.reference(for: selection)
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

    func selectedActivitySelection() throws -> FamilyActivitySelection {
        try targetSelectionCodec.selection(from: lockState.selectedTarget)
    }

    #if DEBUG
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
    #endif

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

    func freeWakeRequest(for lock: ActiveLock) -> WakeRequest? {
        lockState.wakeState.request(for: lock).flatMap { request in
            request.source == .delayed && request.wakesAt > Date() ? request : nil
        }
    }

    var hasWakeCredit: Bool {
        !lockState.wakeState.creditTransactionIDs.isEmpty
    }

    func scheduleFreeWake(for lock: ActiveLock) async -> Bool {
        guard !isHandlingWake else { return false }
        isHandlingWake = true
        defer { isHandlingWake = false; refreshDiagnostics() }
        do {
            _ = try await lockStore.scheduleFreeWake(for: lock, at: Date())
            await synchronizeAndReconcile()
            diagnostics.record("Wake.delayed.scheduled", detail: lock.id.uuidString)
            return true
        } catch {
            recordError("Wake.delayed.failed", error)
            return false
        }
    }

    func cancelFreeWake(for lock: ActiveLock) async {
        guard !isHandlingWake else { return }
        isHandlingWake = true
        defer { isHandlingWake = false; refreshDiagnostics() }
        do {
            try await lockStore.cancelFreeWake(for: lock, at: Date())
            await synchronizeAndReconcile()
            diagnostics.record("Wake.delayed.cancelled", detail: lock.id.uuidString)
        } catch {
            recordError("Wake.delayed.cancel.failed", error)
        }
    }

    func beginWakePurchase(for lock: ActiveLock) async -> Bool {
        guard !isHandlingWake else { return false }
        isHandlingWake = true
        defer { isHandlingWake = false; refreshDiagnostics() }
        do {
            try await lockStore.beginWakePurchase(for: lock, at: Date())
            lockState = try await lockStore.snapshot()
            diagnostics.record("Wake.purchase.started", detail: lock.id.uuidString)
            return true
        } catch {
            recordError("Wake.purchase.begin.failed", error)
            return false
        }
    }

    func abandonWakePurchase() async {
        do {
            try await lockStore.abandonWakePurchase()
            lockState = try await lockStore.snapshot()
        } catch {
            recordError("Wake.purchase.abandon.failed", error, presentAlert: false)
        }
    }

    func deliverWakePurchase(transactionID: UInt64) async -> WakePurchaseDelivery? {
        do {
            let delivery = try await lockStore.deliverWakePurchase(transactionID: transactionID, at: Date())
            await synchronizeAndReconcile()
            if delivery == .unlocked { wakeCompletionID = UUID() }
            diagnostics.record("Wake.purchase.delivered", detail: "transaction=\(transactionID) result=\(delivery)")
            return delivery
        } catch {
            recordError("Wake.purchase.delivery.failed", error)
            return nil
        }
    }

    func useWakeCredit(for lock: ActiveLock) async -> Bool {
        guard !isHandlingWake else { return false }
        isHandlingWake = true
        defer { isHandlingWake = false; refreshDiagnostics() }
        do {
            try await lockStore.useWakeCredit(for: lock, at: Date())
            await synchronizeAndReconcile()
            wakeCompletionID = UUID()
            diagnostics.record("Wake.credit.used", detail: lock.id.uuidString)
            return true
        } catch {
            recordError("Wake.credit.failed", error)
            return false
        }
    }

    @discardableResult
    func selectRecentLockTarget(_ recentTarget: RecentLockTarget) async -> Bool {
        diagnostics.record("RecentTarget.select.started", detail: recentTarget.id.uuidString)
        do {
            let state = try await lockStore.snapshot()
            guard let selection = state.targetSelections.last(where: { $0.id == recentTarget.targetSelectionID }) else {
                throw RecentLockTargetError.targetSelectionNotFound
            }

            _ = try targetSelectionCodec.selection(from: selection)
            try await lockStore.selectTarget(id: selection.id)
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
        guard var single = original.single else { return false }
        single.startsAt = startsAt
        single.duration = duration
        var replacement = original
        replacement.schedule = .single(single)
        return await saveRule(replacement)
    }

    @discardableResult
    func updateRecurringRule(_ original: LockRule, recurrence: RecurrenceRule, enabled: Bool) async -> Bool {
        var replacement = original
        replacement.schedule = .recurring(recurrence)
        replacement.status = enabled ? .scheduled : .disabled
        return await saveRule(replacement)
    }

    private func saveRule(_ replacement: LockRule) async -> Bool {
        guard !isCreatingLock, !isUpdatingLock else { return false }
        isUpdatingLock = true
        defer { isUpdatingLock = false; refreshDiagnostics() }
        do {
            try BearLockSafetyPolicy.validateDuration(replacement.single?.duration ?? replacement.recurrence!.duration)
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

    private func recordError(_ name: String, _ error: Error, presentAlert: Bool = true) {
        if presentAlert { lastErrorMessage = userFacingMessage(for: error) }
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
            case .monitoringCapacityExceeded:
                return L10n.string("Too many schedules are configured. Remove an existing schedule and try again.")
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

        if let wakeError = error as? WakeError {
            switch wakeError {
            case .activeLockNotFound:
                return L10n.string("This lock has already ended.")
            case .freeWakeUnavailable:
                return L10n.string("Less than 30 minutes remain. Wait for the scheduled wake time.")
            case .noWakeRequest:
                return L10n.string("The wake-up request is no longer active.")
            case .noWakeCredit:
                return L10n.string("No wake-up ticket is available.")
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
        return "\(rule.kind.rawValue) rule=\(rule.id.uuidString) schedule=\(rule.schedule)\(activeID)"
    }

    private var latestTargetSelectionCount: Int {
        guard let tokenData = lockState.selectedTarget?.tokenData,
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: tokenData)
        else {
            return lockState.selectedTarget == nil ? 0 : 1
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
