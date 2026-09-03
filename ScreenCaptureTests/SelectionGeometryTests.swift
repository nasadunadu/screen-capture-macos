import CoreGraphics
import XCTest
@testable import ScreenCapture

final class SelectionGeometryTests: XCTestCase {
    func testCornerHandleCanExpandSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let original = CGRect(x: 200, y: 180, width: 400, height: 300)
        let resized = SelectionGeometry.resized(
            rect: original,
            handle: .topRight,
            to: CGPoint(x: 760, y: 650),
            inside: bounds
        )

        XCTAssertEqual(resized, CGRect(x: 200, y: 180, width: 560, height: 470))
    }

    func testResizeCannotInvertOrEscapeScreen() {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 400)
        let original = CGRect(x: 100, y: 100, width: 200, height: 160)
        let resized = SelectionGeometry.resized(
            rect: original,
            handle: .bottomLeft,
            to: CGPoint(x: 450, y: 500),
            inside: bounds
        )

        XCTAssertGreaterThanOrEqual(resized.width, 6)
        XCTAssertGreaterThanOrEqual(resized.height, 6)
        XCTAssertTrue(bounds.contains(resized))
    }

    func testMovingSelectionClampsAtScreenEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 400)
        let moved = SelectionGeometry.moved(
            rect: CGRect(x: 100, y: 120, width: 240, height: 180),
            by: CGSize(width: 500, height: -500),
            inside: bounds
        )

        XCTAssertEqual(moved.origin, CGPoint(x: 260, y: 0))
    }

    func testHandleHitAreaIncludesCornerTolerance() {
        let rect = CGRect(x: 100, y: 100, width: 300, height: 200)
        XCTAssertEqual(
            SelectionGeometry.handle(at: CGPoint(x: 405, y: 305), in: rect),
            .topRight
        )
    }

    func testCursorRectIsClippedAtScreenEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 400)
        let rect = SelectionGeometry.cursorRect(
            CGRect(x: -10, y: 390, width: 20, height: 20),
            inside: bounds
        )

        XCTAssertEqual(rect, CGRect(x: 0, y: 390, width: 10, height: 10))
    }

    func testCursorRectRejectsRegionOutsideScreen() {
        XCTAssertNil(SelectionGeometry.cursorRect(
            CGRect(x: -30, y: -30, width: 10, height: 10),
            inside: CGRect(x: 0, y: 0, width: 500, height: 400)
        ))
        XCTAssertNil(SelectionGeometry.cursorRect(
            CGRect(x: 100, y: 100, width: -4, height: 20),
            inside: CGRect(x: 0, y: 0, width: 500, height: 400)
        ))
    }
}
