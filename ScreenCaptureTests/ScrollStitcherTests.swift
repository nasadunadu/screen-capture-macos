import CoreGraphics
import XCTest
@testable import ScreenCapture

final class ScrollStitcherTests: XCTestCase {
    func testIdenticalFramesDoNotIncreaseHeight() throws {
        let image = makePattern(width: 80, height: 120, offset: 0)
        let analysis = try ScrollStitcher.analyze([image, image])
        XCTAssertLessThanOrEqual(analysis.outputHeight, 124)
        XCTAssertEqual(try ScrollStitcher.stitch([image, image]).height, 120)
    }

    func testOverlappingFramesProduceExpectedLongImage() throws {
        let full = makePattern(width: 90, height: 260, offset: 0)
        guard let first = full.cropping(to: CGRect(x: 0, y: 0, width: 90, height: 160)),
              let second = full.cropping(to: CGRect(x: 0, y: 100, width: 90, height: 160)) else {
            return XCTFail("Could not create fixtures")
        }
        let result = try ScrollStitcher.stitch([first, second])
        XCTAssertEqual(result.width, 90)
        XCTAssertLessThanOrEqual(abs(result.height - 260), 4)
    }

    func testAlignmentReportsTheNewlyRevealedHeight() throws {
        let full = makePattern(width: 180, height: 520, offset: 0)
        guard let first = full.cropping(to: CGRect(x: 0, y: 0, width: 180, height: 320)),
              let second = full.cropping(to: CGRect(x: 0, y: 120, width: 180, height: 320)) else {
            return XCTFail("Could not create fixtures")
        }

        let alignment = try XCTUnwrap(ScrollStitcher.alignment(previous: first, next: second))
        XCTAssertLessThanOrEqual(abs(alignment.scrollDelta - 120), 4)
        XCTAssertLessThanOrEqual(abs(alignment.overlap - 200), 4)
    }

    func testFastScrollWithSmallOverlapStillAligns() throws {
        let full = makePattern(width: 180, height: 700, offset: 0)
        guard let first = full.cropping(to: CGRect(x: 0, y: 0, width: 180, height: 320)),
              let second = full.cropping(to: CGRect(x: 0, y: 290, width: 180, height: 320)) else {
            return XCTFail("Could not create fast-scroll fixtures")
        }

        let alignment = try XCTUnwrap(ScrollStitcher.alignment(previous: first, next: second))
        XCTAssertLessThanOrEqual(abs(alignment.scrollDelta - 290), 4)
        XCTAssertLessThanOrEqual(abs(alignment.overlap - 30), 4)
    }

    func testStickyHeaderDoesNotOverrideScrollingContent() throws {
        let first = makePatternWithStickyHeader(width: 360, height: 600, offset: 0, headerHeight: 90)
        let second = makePatternWithStickyHeader(width: 360, height: 600, offset: 180, headerHeight: 90)

        let alignment = try XCTUnwrap(ScrollStitcher.alignment(previous: first, next: second))
        XCTAssertLessThanOrEqual(abs(alignment.scrollDelta - 180), 5)
    }

    func testPrevalidatedOverlapProducesDeterministicOutputSize() throws {
        let first = makePattern(width: 90, height: 160, offset: 0)
        let second = makePattern(width: 90, height: 160, offset: 60)
        let result = try ScrollStitcher.stitch([first, second], overlaps: [100])
        XCTAssertEqual(result.width, 90)
        XCTAssertEqual(result.height, 220)
    }

    func testIncrementalSegmentsRenderAtNativeWidth() throws {
        let first = makePattern(width: 120, height: 200, offset: 0)
        let next = makePattern(width: 120, height: 200, offset: 50)
        let segment = try ScrollStitcher.newContentSegment(from: next, overlap: 150)
        let result = try ScrollStitcher.render(segments: [first, segment])

        XCTAssertEqual(segment.width, 120)
        XCTAssertEqual(segment.height, 50)
        XCTAssertEqual(result.width, 120)
        XCTAssertEqual(result.height, 250)
    }

    func testMismatchedWidthsFail() {
        let first = makePattern(width: 80, height: 120, offset: 0)
        let second = makePattern(width: 90, height: 120, offset: 0)
        XCTAssertThrowsError(try ScrollStitcher.analyze([first, second]))
    }

    func testLowInformationFramesAreNotAcceptedAsAnArbitraryOverlap() {
        let first = makeSolid(width: 120, height: 180, value: 240)
        let second = makeSolid(width: 120, height: 180, value: 245)

        XCTAssertNil(ScrollStitcher.alignment(previous: first, next: second))
    }

    func testSparseDocumentContentStillAligns() throws {
        let full = makeDocument(width: 240, height: 620)
        let first = try XCTUnwrap(full.cropping(to: CGRect(x: 0, y: 0, width: 240, height: 360)))
        let second = try XCTUnwrap(full.cropping(to: CGRect(x: 0, y: 140, width: 240, height: 360)))

        let alignment = try XCTUnwrap(ScrollStitcher.alignment(previous: first, next: second))
        XCTAssertLessThanOrEqual(abs(alignment.scrollDelta - 140), 4)
    }

    func testAlignmentPerformance() throws {
        let full = makeDocument(width: 900, height: 1_600)
        let first = try XCTUnwrap(full.cropping(to: CGRect(x: 0, y: 0, width: 900, height: 900)))
        let second = try XCTUnwrap(full.cropping(to: CGRect(x: 0, y: 240, width: 900, height: 900)))

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<3 {
                XCTAssertNotNil(ScrollStitcher.alignment(previous: first, next: second))
            }
        }
    }

    private func makePattern(width: Int, height: Int, offset: Int) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = UInt8(truncatingIfNeeded: ((y + offset) * 73) ^ (x * 19) ^ ((y + offset) >> 2))
                let index = (y * width + x) * 4
                bytes[index] = value
                bytes[index + 1] = UInt8(truncatingIfNeeded: Int(value) * 3)
                bytes[index + 2] = UInt8(truncatingIfNeeded: Int(value) * 7)
                bytes[index + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private func makePatternWithStickyHeader(
        width: Int,
        height: Int,
        offset: Int,
        headerHeight: Int
    ) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let sourceY = y < headerHeight ? y : y + offset
                let value = UInt8(truncatingIfNeeded: (sourceY * 73) ^ (x * 19) ^ (sourceY >> 2))
                let index = (y * width + x) * 4
                bytes[index] = value
                bytes[index + 1] = UInt8(truncatingIfNeeded: Int(value) * 3)
                bytes[index + 2] = UInt8(truncatingIfNeeded: Int(value) * 7)
                bytes[index + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private func makeSolid(width: Int, height: Int, value: UInt8) -> CGImage {
        var bytes = [UInt8](repeating: value, count: width * height * 4)
        for index in stride(from: 3, to: bytes.count, by: 4) { bytes[index] = 255 }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private func makeDocument(width: Int, height: Int) -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 3, to: bytes.count, by: 4) { bytes[index] = 255 }
        for y in stride(from: 14, to: height, by: 24) {
            let lineWidth = 70 + (y * 37) % max(71, width - 24)
            for row in y..<min(y + 3, height) {
                for x in 12..<min(lineWidth, width - 8) {
                    let index = (row * width + x) * 4
                    bytes[index] = 35
                    bytes[index + 1] = 35
                    bytes[index + 2] = 35
                }
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
