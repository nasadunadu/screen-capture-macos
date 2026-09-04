import XCTest
@testable import ScreenCapture

final class ScreenCapturePermissionTests: XCTestCase {
    func testPermissionRequestGateOnlyRequestsOncePerLaunch() {
        var gate = ScreenCapturePermissionRequestGate()

        XCTAssertTrue(gate.shouldRequest(isGranted: false))
        XCTAssertFalse(gate.shouldRequest(isGranted: false))
        XCTAssertFalse(gate.shouldRequest(isGranted: true))
    }

    func testGrantedPermissionDoesNotConsumeRequestOpportunity() {
        var gate = ScreenCapturePermissionRequestGate()

        XCTAssertFalse(gate.shouldRequest(isGranted: true))
        XCTAssertTrue(gate.shouldRequest(isGranted: false))
    }

    func testPermissionDeniedUsesRecoveryFlow() {
        XCTAssertTrue(CaptureServiceError.permissionDenied.needsPermissionRecovery)
        XCTAssertFalse(CaptureServiceError.captureFailed.needsPermissionRecovery)
    }

    func testSettingsDeepLinkTargetsScreenCapturePrivacyPane() {
        XCTAssertTrue(
            ScreenCapturePermission.systemSettingsURLs.contains {
                $0.absoluteString.contains("Privacy_ScreenCapture")
            }
        )
    }
}
