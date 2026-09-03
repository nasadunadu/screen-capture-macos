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
}
