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
}

final class KeyboardShortcutDefinitionTests: XCTestCase {
    func testDefaultShortcutDisplayNames() {
        XCTAssertEqual(KeyboardShortcutDefinition.normalDefault.displayName, "⌘4")
        XCTAssertEqual(KeyboardShortcutDefinition.longCaptureDefault.displayName, "⌘5")
    }
}
