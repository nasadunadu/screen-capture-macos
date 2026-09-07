import AppKit
import XCTest
@testable import ScreenCapture

final class SelectionInteractionTests: XCTestCase {
    @MainActor
    func testInitialRegionDragMovesCropThenExplicitToolDrawsOnFirstDrag() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let context = try XCTUnwrap(CGContext(data: nil, width: 800, height: 600,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let document = AnnotationDocument()
        let view = SelectionOverlayView(frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            image: try XCTUnwrap(context.makeImage()), screen: screen, windows: [],
            mode: .region, document: document)
        func event(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: y),
                modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try event(.leftMouseDown, 100, 100))
        view.mouseDragged(with: try event(.leftMouseDragged, 400, 350))
        view.mouseUp(with: try event(.leftMouseUp, 400, 350))
        XCTAssertTrue(view.hitTest(CGPoint(x: 200, y: 200)) === view)
        view.mouseDown(with: try event(.leftMouseDown, 200, 200))
        view.mouseDragged(with: try event(.leftMouseDragged, 250, 230))
        view.mouseUp(with: try event(.leftMouseUp, 250, 230))
        XCTAssertTrue(document.elements.isEmpty)
        var capturedRect: CGRect?
        view.onResult = { result in
            if case let .region(region) = result { capturedRect = region.rect }
        }
        view.complete(action: .defaultExport, style: document.style)
        XCTAssertEqual(capturedRect, CGRect(x: 150, y: 130, width: 300, height: 250))

        // The crop remains resizable after being moved, even though a canvas exists.
        XCTAssertTrue(view.hitTest(CGPoint(x: 450, y: 380)) === view)
        view.mouseDown(with: try event(.leftMouseDown, 450, 380))
        view.mouseDragged(with: try event(.leftMouseDragged, 480, 400))
        view.mouseUp(with: try event(.leftMouseUp, 480, 400))
        view.complete(action: .defaultExport, style: document.style)
        XCTAssertEqual(capturedRect, CGRect(x: 150, y: 130, width: 330, height: 270))

        // An overlapping toolbar must stay clickable instead of initiating a region move.
        let toolbar = NSView(frame: .zero)
        view.installToolbar(toolbar)
        view.keepToolbarVisible()
        toolbar.frame = CGRect(x: 200, y: 150, width: 80, height: 40)
        XCTAssertTrue(view.hitTest(CGPoint(x: 220, y: 160)) === toolbar)

        document.tool = .arrow
        let canvas = try XCTUnwrap(view.hitTest(CGPoint(x: 250, y: 230)) as? AnnotationCanvasView)
        canvas.mouseDown(with: try event(.leftMouseDown, 230, 200))
        canvas.mouseDragged(with: try event(.leftMouseDragged, 320, 280))
        canvas.mouseUp(with: try event(.leftMouseUp, 320, 280))
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements.first?.tool, .arrow)
    }
}
