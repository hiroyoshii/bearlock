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
    var usesSummaryFixtures = false

    func summary(from reference: LockTargetSelectionRef?) throws -> TargetSelectionSummary {
        var result = TargetSelectionSummary.empty
        guard usesSummaryFixtures else { return result }
        switch reference?.id.uuidString {
        case "11111111-1111-1111-1111-111111111111":
            result.previewApplicationNames = ["Messages", "Video", "Games"]
        case "13131313-1313-1313-1313-131313131313":
            result.previewApplicationNames = ["Books", "Music"]
        default:
            break
        }
        result.applications = result.previewApplicationNames.count
        return result
    }

    func selection(from reference: LockTargetSelectionRef?) throws -> FamilyActivitySelection { FamilyActivitySelection() }
    func reference(for selection: FamilyActivitySelection) throws -> LockTargetSelectionRef {
        LockTargetSelectionRef(displayName: "UI test targets")
    }
}

struct NoopShieldController: ShieldControlling {
    func reconcile(state: LockState, at date: Date) throws {}
}

struct NoopScheduleController: ScheduleControlling {
    func synchronize(_ state: LockState, at now: Date) throws {}
}

// Used only by the existing --ui-testing launch path; no system prompt is simulated as real consent.
final class UITestingAuthorizationService: AuthorizationServicing {
    private var status: AuthorizationState
    private let deny: Bool
    init(status: AuthorizationState, deny: Bool) { self.status = status; self.deny = deny }
    func currentStatus() -> AuthorizationState { status }
    func requestAuthorization() async throws { status = deny ? .denied : .approved }
}

// Fault injection is reachable only from BearLockAppModel's --ui-testing path.
struct UITestingScheduleController: ScheduleControlling {
    func synchronize(_ state: LockState, at now: Date) throws {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-monitoring-failure") {
            throw CocoaError(.fileReadUnknown)
        }
    }
}
struct UITestingLockRepository: LockRepository {
    let base: JSONFileLockRepository
    func load() throws -> LockState {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-read-failure") {
            throw CocoaError(.fileReadUnknown)
        }
        return try base.load()
    }
    func save(_ state: LockState) throws { try base.save(state) }
}
