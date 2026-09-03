import XCTest
@testable import ScreenCapture

final class ScreenCapturePermissionTests: XCTestCase {
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
