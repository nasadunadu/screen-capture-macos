import XCTest
@testable import ScreenCapture

final class ScrollStitcherCapacityTests: XCTestCase {
    func testRejectsExcessiveHeightBeforeRendering() {
        XCTAssertThrowsError(
            try ScrollStitcher.validateOutputSize(width: 1, height: ScrollStitcher.maximumOutputHeight + 1)
        ) { error in
            guard case StitchError.outputTooTall = error else {
                return XCTFail("Expected outputTooTall, got \(error)")
            }
        }
    }

    func testRejectsExcessivePixelCountBeforeAllocatingCanvas() {
        XCTAssertThrowsError(
            try ScrollStitcher.validateOutputSize(
                width: 6_000,
                height: ScrollStitcher.maximumOutputPixels / 6_000 + 1
            )
        ) { error in
            guard case StitchError.outputTooLarge = error else {
                return XCTFail("Expected outputTooLarge, got \(error)")
            }
        }
    }

    func testMaximumOutputKeepsTwoRGBAImagesWithinMemoryBudget() {
        let estimatedWorkingSet = ScrollStitcher.maximumOutputPixels * 4 * 2
        XCTAssertLessThanOrEqual(estimatedWorkingSet, 512 * 1_024 * 1_024)
    }
}
