import CoreGraphics
import XCTest
@testable import ScreenCapture

final class AnnotationEditorLayoutTests: XCTestCase {
    func testDimmingFramesCoverOnlyOutsideSelection() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let selection = CGRect(x: 320, y: 180, width: 720, height: 540)
        let frames = AnnotationEditorLayout.dimmingFrames(
            screenFrame: screen,
            selectionFrame: selection
        )

        XCTAssertEqual(frames.count, 4)
        XCTAssertTrue(frames.allSatisfy { !$0.intersects(selection) })
        XCTAssertEqual(frames.reduce(0) { $0 + $1.width * $1.height }, screen.width * screen.height - selection.width * selection.height)
    }

    func testToolbarAlignsItsRightEdgeBelowSelection() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 860)
        let selection = CGRect(x: 300, y: 180, width: 980, height: 560)
        let toolbar = AnnotationEditorLayout.toolbarFrame(
            visibleFrame: visible,
            selectionFrame: selection,
            desiredSize: CGSize(width: 940, height: 62)
        )

        XCTAssertEqual(toolbar.maxX, selection.maxX)
        XCTAssertEqual(toolbar.maxY, selection.minY - 8)
        XCTAssertTrue(visible.contains(toolbar))
    }

    func testToolbarMovesAboveSelectionWhenBottomSpaceIsUnavailable() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 860)
        let selection = CGRect(x: 260, y: 20, width: 920, height: 600)
        let toolbar = AnnotationEditorLayout.toolbarFrame(
            visibleFrame: visible,
            selectionFrame: selection,
            desiredSize: CGSize(width: 900, height: 62)
        )

        XCTAssertEqual(toolbar.minY, selection.maxY + 8)
        XCTAssertTrue(visible.contains(toolbar))
    }
}
