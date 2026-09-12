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

    func activate(_ selection: LockTargetSelectionRef) throws {}
}

struct NoopShieldController: ShieldControlling {
    func applyShield(for activeLock: ActiveLock, selection: LockTargetSelectionRef?) throws {}
    func clearShield() {}
}

struct NoopScheduleController: ScheduleControlling {
    func schedule(_ rule: LockRule) throws {}
    func cancel(_ rule: LockRule) throws {}
}

// Used only by the existing --ui-testing launch path; no system prompt is simulated as real consent.
final class UITestingAuthorizationService: AuthorizationServicing {
    private var status: AuthorizationState
    private let deny: Bool
    init(status: AuthorizationState, deny: Bool) { self.status = status; self.deny = deny }
    func currentStatus() -> AuthorizationState { status }
    func requestAuthorization() async throws { status = deny ? .denied : .approved }
}
