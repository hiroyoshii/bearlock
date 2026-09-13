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

struct PreviewTargetSelectionCodec: TargetSelectionCoding {
    func selection(from reference: LockTargetSelectionRef?) throws -> FamilyActivitySelection { FamilyActivitySelection() }
    func reference(for selection: FamilyActivitySelection) throws -> LockTargetSelectionRef {
        LockTargetSelectionRef(displayName: "UI test targets")
    }
}

struct NoopShieldController: ShieldControlling {
    func applyShield(selections: [LockTargetSelectionRef]) throws {}
}

struct NoopScheduleController: ScheduleControlling {
    func synchronize(_ rules: [LockRule], at now: Date) throws {}
}

// Used only by the existing --ui-testing launch path; no system prompt is simulated as real consent.
final class UITestingAuthorizationService: AuthorizationServicing {
    private var status: AuthorizationState
    private let deny: Bool
    init(status: AuthorizationState, deny: Bool) { self.status = status; self.deny = deny }
    func currentStatus() -> AuthorizationState { status }
    func requestAuthorization() async throws { status = deny ? .denied : .approved }
}
