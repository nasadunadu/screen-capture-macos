import XCTest
@testable import ScreenCapture

final class CaptureWorkflowGateTests: XCTestCase {
    func testRejectsOverlappingCaptureWorkflowsUntilReleased() {
        var gate = CaptureWorkflowGate()

        let first = gate.acquire()
        XCTAssertNotNil(first)
        XCTAssertTrue(gate.isActive)
        XCTAssertNil(gate.acquire())

        XCTAssertTrue(gate.release(first!))

        XCTAssertFalse(gate.isActive)
        XCTAssertNotNil(gate.acquire())
    }

    func testStaleWorkflowCannotReleaseNewWorkflow() {
        var gate = CaptureWorkflowGate()
        let first = gate.acquire()!
        XCTAssertTrue(gate.release(first))
        let second = gate.acquire()!

        XCTAssertFalse(gate.release(first))
        XCTAssertTrue(gate.isActive(second))
    }
}
