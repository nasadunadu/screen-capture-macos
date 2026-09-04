import CoreGraphics
import XCTest
@testable import ScreenCapture

final class CaptureGeometryTests: XCTestCase {
    func testNativePixelSizeUsesRetinaScale() {
        let size = CaptureGeometry.nativePixelSize(
            logicalSize: CGSize(width: 1920, height: 1080),
            scale: 2
        )
        XCTAssertEqual(size, CGSize(width: 3840, height: 2160))
    }

    func testNativePixelSizeNeverUpscalesFromInvalidScale() {
        let size = CaptureGeometry.nativePixelSize(
            logicalSize: CGSize(width: 400, height: 300),
            scale: 0
        )
        XCTAssertEqual(size, CGSize(width: 400, height: 300))
    }

    func testNativePixelSizeRejectsNonFiniteInputs() {
        XCTAssertEqual(
            CaptureGeometry.nativePixelSize(
                logicalSize: CGSize(width: CGFloat.nan, height: CGFloat.infinity),
                scale: CGFloat.nan
            ),
            CGSize(width: 1, height: 1)
        )
    }

    func testCropRejectsNonFiniteSelection() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 10,
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = context.makeImage()!

        XCTAssertNil(CaptureGeometry.crop(
            image: image,
            selection: CGRect(x: CGFloat.nan, y: 0, width: 4, height: 4),
            canvasSize: CGSize(width: 10, height: 10)
        ))
    }

    func testDisplayMatcherKeepsPreferredDisplayWhenItIsStillAvailable() {
        let displayID = ScreenDisplayMatcher.selectDisplayID(
            preferredID: 7,
            preferredFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            currentScreens: [
                ScreenDisplayCandidate(displayID: 4, frame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)),
                ScreenDisplayCandidate(displayID: 7, frame: CGRect(x: 1_920, y: 0, width: 1_440, height: 900))
            ],
            availableDisplayIDs: [4, 7]
        )

        XCTAssertEqual(displayID, 7)
    }

    func testDisplayMatcherRecoversWhenAStaleDisplayIDKeepsTheSameFrame() {
        let displayID = ScreenDisplayMatcher.selectDisplayID(
            preferredID: 3,
            preferredFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
            currentScreens: [
                ScreenDisplayCandidate(displayID: 4, frame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080))
            ],
            availableDisplayIDs: [4]
        )

        XCTAssertEqual(displayID, 4)
    }

    func testDisplayMatcherFallsBackToCurrentMainScreenAfterTopologyChange() {
        let displayID = ScreenDisplayMatcher.selectDisplayID(
            preferredID: 3,
            preferredFrame: .zero,
            currentScreens: [
                ScreenDisplayCandidate(displayID: 4, frame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080)),
                ScreenDisplayCandidate(displayID: 8, frame: CGRect(x: -1_440, y: 0, width: 1_440, height: 900))
            ],
            availableDisplayIDs: [4, 8]
        )

        XCTAssertEqual(displayID, 4)
    }
}

final class KeyboardShortcutDefinitionTests: XCTestCase {
    func testDefaultShortcutDisplayNames() {
        XCTAssertEqual(KeyboardShortcutDefinition.normalDefault.displayName, "⌘4")
        XCTAssertEqual(KeyboardShortcutDefinition.longCaptureDefault.displayName, "⌘5")
    }
}
