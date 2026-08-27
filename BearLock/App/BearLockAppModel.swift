import Foundation
import BearLockCore
import FamilyControls

@MainActor
final class BearLockAppModel: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationState = .unknown
    @Published private(set) var lockState = LockState()
    @Published private(set) var isCreatingLock = false
    @Published private(set) var isUpdatingLock = false
    @Published var lastErrorMessage: String?

    let authorizationService: AuthorizationServicing
    let targetSelectionStore: TargetSelectionStoring
    let shieldController: ShieldControlling
    let scheduleController: ScheduleControlling
    private let lockStore: LockStore
    private let planner: LockPlanner

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

        do {
            var state = try repository.load()
            if state.targetSelections.isEmpty {
                state.targetSelections = [target]
                try repository.save(state)
            }
        } catch {
            try? repository.save(LockState(targetSelections: [target]))
        }
    }

    func refresh() async {
        let now = Date()
        authorizationStatus = authorizationService.currentStatus()
        lockState = await lockStore.snapshot()

        if let completed = try? await lockStore.completeActiveLock(at: now) {
            shieldController.clearShield(for: completed)
            lockState = await lockStore.snapshot()
        }

        _ = try? await lockStore.completeExpiredOneShotRules(at: now)
        lockState = await lockStore.snapshot()

        if lockState.activeLock == nil,
           let rule = planner.scheduledRuleContaining(now, in: lockState.rules) {
            let active = planner.activeLock(from: rule, intervalStart: rule.startsAt)
            do {
                try await lockStore.activate(active)
                shieldController.applyShield(for: active)
                lockState = await lockStore.snapshot()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func requestAuthorization() async {
        do {
            try await authorizationService.requestAuthorization()
            authorizationStatus = authorizationService.currentStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
            authorizationStatus = authorizationService.currentStatus()
        }
    }

    func saveSelection(_ selection: FamilyActivitySelection) async {
        do {
            let ref = try targetSelectionStore.save(selection)
            try await lockStore.saveTargetSelection(ref)
            lockState = await lockStore.snapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func createLock(_ request: LockCreationRequest) async -> Bool {
        isCreatingLock = true
        defer { isCreatingLock = false }

        do {
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
                try scheduleController.schedule(rule)
                let active = planner.activeLock(from: rule, intervalStart: now)
                do {
                    try await lockStore.activate(active)
                    shieldController.applyShield(for: active)
                } catch {
                    try? scheduleController.cancel(rule)
                    try? await lockStore.clearActiveLock(id: active.id)
                    throw error
                }
            case .delayed, .fixedDateTime, .recurring:
                try scheduleController.schedule(rule)
                do {
                    try await lockStore.addRule(rule)
                } catch {
                    try? scheduleController.cancel(rule)
                    throw error
                }
            }

            lockState = await lockStore.snapshot()
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteScheduledRule(_ rule: LockRule) async {
        do {
            try await lockStore.deleteRule(id: rule.id, now: Date())
            try scheduleController.cancel(rule)
            lockState = await lockStore.snapshot()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func updateScheduledRule(_ original: LockRule, startsAt: Date, duration: TimeInterval) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }

        do {
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
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateRecurringRule(_ original: LockRule, recurrence: RecurrenceRule) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }

        do {
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
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func setRecurringRule(_ rule: LockRule, enabled: Bool) async -> Bool {
        isUpdatingLock = true
        defer { isUpdatingLock = false }

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
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }
}
