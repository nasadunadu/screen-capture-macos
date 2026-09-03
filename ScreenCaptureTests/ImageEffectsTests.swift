import CoreGraphics
import XCTest
@testable import ScreenCapture

final class ImageEffectsTests: XCTestCase {
    func testRoundedCornersKeepNativeDimensionsAndClearCornerPixels() throws {
        let source = makeSolidImage(width: 40, height: 30)
        let output = ImageEffects.apply(
            to: source,
            options: options(cornerRadius: 10, shadowEnabled: false)
        )

        XCTAssertEqual(output.width, 40)
        XCTAssertEqual(output.height, 30)
        XCTAssertEqual(try alpha(in: output, x: 0, y: 0), 0)
        XCTAssertGreaterThan(try alpha(in: output, x: 20, y: 15), 0)
    }

    func testShadowCreatesVisiblePixelsInAddedPadding() throws {
        let source = makeSolidImage(width: 40, height: 30)
        let output = ImageEffects.apply(
            to: source,
            options: options(cornerRadius: 8, shadowEnabled: true)
        )

        XCTAssertEqual(output.width, 96)
        XCTAssertEqual(output.height, 86)
        let paddingContainsShadow = try (0..<output.height).contains { y in
            try (0..<28).contains { x in try alpha(in: output, x: x, y: y) > 0 }
        }
        XCTAssertTrue(paddingContainsShadow)
    }

    func testEverySettingsSliderRadiusRendersAtNativeContentResolution() {
        let source = makeSolidImage(width: 80, height: 60)

        for radius in 0...32 {
            let output = ImageEffects.apply(
                to: source,
                options: options(cornerRadius: CGFloat(radius), shadowEnabled: false)
            )
            XCTAssertEqual(output.width, source.width, "radius: \(radius)")
            XCTAssertEqual(output.height, source.height, "radius: \(radius)")
        }
    }

    private func options(cornerRadius: CGFloat, shadowEnabled: Bool) -> ExportOptions {
        ExportOptions(
            format: .png,
            jpegQuality: 0.92,
            directoryURL: FileManager.default.temporaryDirectory,
            copyAfterSave: false,
            playSound: false,
            cornerRadius: cornerRadius,
            shadowEnabled: shadowEnabled
        )
    }

    private func makeSolidImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func alpha(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(
            image,
            in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height)
        )
        return pixel[3]
    }
}
