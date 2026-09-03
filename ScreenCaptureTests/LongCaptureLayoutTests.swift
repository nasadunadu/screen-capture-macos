import CoreGraphics
import XCTest
@testable import ScreenCapture

final class LongCaptureLayoutTests: XCTestCase {
    func testGuideMasksNeverOverlapCaptureSource() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let selection = CGRect(x: 120, y: 90, width: 720, height: 680)
        let masks = LongCaptureLayout.maskDescriptors(
            screenFrame: screen,
            selectionFrame: selection
        )

        XCTAssertEqual(masks.count, 4)
        XCTAssertTrue(masks.allSatisfy { !$0.frame.intersects(selection) })
    }

    func testPreviewUsesRightSideWithoutTouchingCaptureSource() throws {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 860)
        let selection = CGRect(x: 80, y: 80, width: 560, height: 700)
        let preview = try XCTUnwrap(LongCaptureLayout.previewFrame(
            visibleFrame: visible,
            selectionFrame: selection
        ))

        XCTAssertGreaterThan(preview.minX, selection.maxX)
        XCTAssertFalse(preview.intersects(selection))
        XCTAssertTrue(visible.contains(preview))
    }

    func testPreviewIsHiddenRatherThanOverlayingWideSelection() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 860)
        let selection = CGRect(x: 20, y: 80, width: 1_400, height: 700)

        XCTAssertNil(LongCaptureLayout.previewFrame(
            visibleFrame: visible,
            selectionFrame: selection
        ))
    }
}
