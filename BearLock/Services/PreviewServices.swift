import BearLockCore
import FamilyControls
import Foundation

struct PreviewAuthorizationService: AuthorizationServicing {
    var status: AuthorizationState = .unknown

    func currentStatus() -> AuthorizationState {
        status
    }

    func requestAuthorization() async throws {}
}

struct PreviewTargetSelectionStore: TargetSelectionStoring {
    func load() throws -> FamilyActivitySelection {
        FamilyActivitySelection()
    }

    func save(_ selection: FamilyActivitySelection) throws -> LockTargetSelectionRef {
        LockTargetSelectionRef(displayName: "UI test targets")
    }
}

struct NoopShieldController: ShieldControlling {
    func applyShield(for activeLock: ActiveLock) {}
    func clearShield(for activeLock: ActiveLock) {}
}

struct NoopScheduleController: ScheduleControlling {
    func schedule(_ rule: LockRule) throws {}
    func cancel(_ rule: LockRule) throws {}
}
