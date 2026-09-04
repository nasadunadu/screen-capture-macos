import SwiftUI
import XCTest
@testable import ScreenCapture

final class AnnotationToolbarTests: XCTestCase {
    @MainActor
    func testPrimaryToolOrderMatchesCompactAnnotationWorkflow() {
        let tools = AnnotationToolbarView.primaryTools
        XCTAssertEqual(
            tools,
            [.rectangle, .ellipse, .line, .arrow, .pen, .text]
        )
        XCTAssertFalse(tools.contains(.select))
        XCTAssertFalse(tools.contains(.spotlight))
        XCTAssertEqual(AnnotationCanvasView.keyboardTools, tools)
    }

    @MainActor
    func testArrowIsActiveBeforeTheFirstAnnotationDrag() {
        XCTAssertEqual(AnnotationDocument().tool, .arrow)
    }

    @MainActor
    func testFirstToolSelectionImmediatelyPresentsLineWidthOptions() {
        XCTAssertEqual(
            AnnotationToolbarView.optionsToolAfterSelecting(
                .line,
                currentTool: .arrow,
                presentedTool: nil
            ),
            .line
        )
        XCTAssertEqual(
            AnnotationToolbarView.optionsToolAfterSelecting(
                .arrow,
                currentTool: .arrow,
                presentedTool: nil
            ),
            .arrow
        )
        XCTAssertNil(
            AnnotationToolbarView.optionsToolAfterSelecting(
                .arrow,
                currentTool: .arrow,
                presentedTool: .arrow
            )
        )
    }

    @MainActor
    func testLineAndArrowUseCenteredPrecisionCursor() {
        XCTAssertTrue(AnnotationPrecisionCursor.isUsed(for: .line))
        XCTAssertTrue(AnnotationPrecisionCursor.isUsed(for: .arrow))
        XCTAssertFalse(AnnotationPrecisionCursor.isUsed(for: .rectangle))
        XCTAssertFalse(AnnotationPrecisionCursor.isUsed(for: .pen))
        XCTAssertEqual(AnnotationPrecisionCursor.cursor.image.size, AnnotationPrecisionCursor.imageSize)
        XCTAssertEqual(AnnotationPrecisionCursor.cursor.hotSpot, AnnotationPrecisionCursor.hotSpot)
    }

    @MainActor
    func testToolbarFitsACompactSingleRow() {
        let view = AnnotationToolbarView(
            document: AnnotationDocument(),
            supportsLongCapture: true,
            onLongCapture: {},
            onSave: {},
            onSaveAs: {},
            onCancel: {}
        )
        let size = NSHostingView(rootView: view).fittingSize

        XCTAssertGreaterThan(size.width, 500)
        XCTAssertLessThan(size.width, 820)
        XCTAssertLessThanOrEqual(size.height, 64)
    }

    @MainActor
    func testEditorToolbarStaysInSingleRetainedViewHierarchy() {
        let root = AnnotationEditorRootView(frame: CGRect(x: 0, y: 0, width: 500, height: 400))
        let canvas = NSView(frame: CGRect(x: 0, y: 80, width: 500, height: 320))
        let toolbar = NSView(frame: .zero)

        root.addCanvas(canvas)
        root.installToolbar(toolbar, frame: CGRect(x: 100, y: 10, width: 300, height: 62))

        XCTAssertTrue(canvas.superview === root)
        XCTAssertTrue(toolbar.superview === root)
        XCTAssertTrue(root.subviews.last === toolbar)

        toolbar.isHidden = true
        root.keepToolbarVisible()
        XCTAssertFalse(toolbar.isHidden)
        XCTAssertTrue(toolbar.superview === root)
    }
}
