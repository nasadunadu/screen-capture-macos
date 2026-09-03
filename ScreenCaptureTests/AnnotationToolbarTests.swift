import SwiftUI
import XCTest
@testable import ScreenCapture

final class AnnotationToolbarTests: XCTestCase {
    @MainActor
    func testPrimaryToolOrderMatchesCompactAnnotationWorkflow() {
        let tools = AnnotationToolbarView.primaryTools
        XCTAssertEqual(
            tools,
            [.rectangle, .ellipse, .line, .arrow, .pen, .text, .spotlight]
        )
        XCTAssertFalse(tools.contains(.select))
        XCTAssertEqual(AnnotationCanvasView.keyboardTools, tools)
    }

    @MainActor
    func testArrowIsActiveBeforeTheFirstAnnotationDrag() {
        XCTAssertEqual(AnnotationDocument().tool, .arrow)
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
    func testEditorToolbarPanelStaysAboveCanvasAndDoesNotHideOnDeactivate() {
        let canvas = EditorPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        let toolbar = EditorPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        toolbar.keepAbove(canvas)

        XCTAssertFalse(toolbar.hidesOnDeactivate)
        XCTAssertTrue(canvas.childWindows?.contains { $0 === toolbar } == true)

        toolbar.orderOut(nil)
        canvas.orderOut(nil)
        toolbar.close()
        canvas.close()
    }
}
