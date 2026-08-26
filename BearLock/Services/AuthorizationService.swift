import FamilyControls
import Foundation

enum AuthorizationState: Equatable {
    case unknown
    case approved
    case denied
}

protocol AuthorizationServicing {
    func currentStatus() -> AuthorizationState
    func requestAuthorization() async throws
}

struct FamilyControlsAuthorizationService: AuthorizationServicing {
    func currentStatus() -> AuthorizationState {
        let status = AuthorizationCenter.shared.authorizationStatus

        switch status {
        case .approved:
            return .approved
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
