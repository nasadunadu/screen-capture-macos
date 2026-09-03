import AppKit
import XCTest
@testable import ScreenCapture

@MainActor
final class AnnotationDocumentTests: XCTestCase {
    func testUndoAndRedoRestoreDocumentMutations() {
        let document = AnnotationDocument()
        document.beginMutation()
        document.append(element(tool: .rectangle))

        XCTAssertEqual(document.elements.count, 1)
        document.undo()
        XCTAssertTrue(document.elements.isEmpty)
        document.redo()
        XCTAssertEqual(document.elements.count, 1)
    }

    func testRemovingSelectedElementCanBeUndone() {
        let document = AnnotationDocument()
        let annotation = element(tool: .arrow)
        document.beginMutation()
        document.append(annotation)

        document.removeSelected()
        XCTAssertTrue(document.elements.isEmpty)
        document.undo()
        XCTAssertEqual(document.elements.map(\.id), [annotation.id])
    }

    func testTranslationMovesFreehandPointsAndEndpointsTogether() {
        var annotation = AnnotationElement(
            tool: .pen,
            start: CGPoint(x: 1, y: 2),
            end: CGPoint(x: 4, y: 5),
            points: [CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 5)],
            style: AnnotationStyle()
        )

        annotation.translate(by: CGSize(width: 10, height: -2))

        XCTAssertEqual(annotation.start, CGPoint(x: 11, y: 0))
        XCTAssertEqual(annotation.end, CGPoint(x: 14, y: 3))
        XCTAssertEqual(annotation.points, [CGPoint(x: 11, y: 0), CGPoint(x: 14, y: 3)])
    }

    func testColorUpdatesDefaultsAndSelectedAnnotation() {
        let document = AnnotationDocument()
        let annotation = element(tool: .arrow)
        document.beginMutation()
        document.append(annotation)

        document.setColor(.systemBlue)

        XCTAssertTrue(document.style.color.isEqual(NSColor.systemBlue))
        XCTAssertTrue(document.activeColor.isEqual(NSColor.systemBlue))
        XCTAssertTrue(document.element(id: annotation.id)?.style.color.isEqual(NSColor.systemBlue) == true)
    }

    func testSelectedAnnotationColorChangeCanBeUndone() {
        let document = AnnotationDocument()
        let annotation = element(tool: .rectangle)
        document.beginMutation()
        document.append(annotation)
        document.setColor(.systemPurple)

        document.undo()

        XCTAssertTrue(document.element(id: annotation.id)?.style.color.isEqual(NSColor.systemRed) == true)
    }

    func testColorDoesNotMutateSelectedColorlessAnnotation() {
        let document = AnnotationDocument()
        let annotation = element(tool: .spotlight)
        document.beginMutation()
        document.append(annotation)

        document.setColor(.systemGreen)

        XCTAssertTrue(document.style.color.isEqual(NSColor.systemGreen))
        XCTAssertTrue(document.element(id: annotation.id)?.style.color.isEqual(NSColor.systemRed) == true)
    }

    func testLineWidthUpdatesDefaultsAndSelectedAnnotation() {
        let document = AnnotationDocument()
        let annotation = element(tool: .arrow)
        document.beginMutation()
        document.append(annotation)

        document.setLineWidth(12)

        XCTAssertEqual(document.style.lineWidth, 12)
        XCTAssertEqual(document.activeLineWidth, 12)
        XCTAssertEqual(document.element(id: annotation.id)?.style.lineWidth, 12)
    }

    func testContinuousLineWidthAdjustmentCreatesOneUndoStep() {
        let document = AnnotationDocument()
        let annotation = element(tool: .pen)
        document.beginMutation()
        document.append(annotation)

        document.beginLineWidthAdjustment()
        document.setLineWidth(8)
        document.setLineWidth(14)
        document.endLineWidthAdjustment()
        document.undo()

        XCTAssertEqual(document.element(id: annotation.id)?.style.lineWidth, 5)
        document.undo()
        XCTAssertTrue(document.elements.isEmpty)
    }

    func testLineWidthIsClampedAndDoesNotChangeSpotlightStyle() {
        let document = AnnotationDocument()
        let annotation = element(tool: .spotlight)
        document.beginMutation()
        document.append(annotation)

        document.setLineWidth(100)

        XCTAssertEqual(document.style.lineWidth, 18)
        XCTAssertEqual(document.element(id: annotation.id)?.style.lineWidth, 5)
    }

    func testArrowGeometryTapersFromTailIntoLargerHead() throws {
        let geometry = try XCTUnwrap(AnnotationArrowGeometry.make(
            start: CGPoint(x: 10, y: 20),
            end: CGPoint(x: 210, y: 20),
            lineWidth: 5
        ))

        XCTAssertEqual(geometry.points.first, CGPoint(x: 10, y: 20))
        XCTAssertEqual(geometry.points[3], CGPoint(x: 210, y: 20))
        let shaftWidth = geometry.points[1].y - geometry.points[5].y
        let headWidth = geometry.points[2].y - geometry.points[4].y
        XCTAssertGreaterThan(shaftWidth, 0)
        XCTAssertGreaterThan(headWidth, shaftWidth * 2)
    }

    func testArrowBoundsIncludeHeadBeyondEndpointCenterline() throws {
        let geometry = try XCTUnwrap(AnnotationArrowGeometry.make(
            start: CGPoint(x: 0, y: 60),
            end: CGPoint(x: 120, y: 60),
            lineWidth: 8
        ))

        XCTAssertEqual(geometry.bounds.minX, 0)
        XCTAssertEqual(geometry.bounds.maxX, 120)
        XCTAssertLessThan(geometry.bounds.minY, 60)
        XCTAssertGreaterThan(geometry.bounds.maxY, 60)
    }

    func testArrowGeometryRejectsZeroLengthInput() {
        XCTAssertNil(AnnotationArrowGeometry.make(
            start: CGPoint(x: 40, y: 40),
            end: CGPoint(x: 40, y: 40),
            lineWidth: 5
        ))
    }

    func testCanvasAcceptsFirstMouseAfterToolbarFocusChange() throws {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let canvas = AnnotationCanvasView(
            image: image,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            document: AnnotationDocument()
        )

        XCTAssertTrue(canvas.acceptsFirstMouse(for: nil))
    }

    private func element(tool: AnnotationTool) -> AnnotationElement {
        AnnotationElement(
            tool: tool,
            start: CGPoint(x: 10, y: 10),
            end: CGPoint(x: 40, y: 40),
            style: AnnotationStyle()
        )
    }
}
