import CoreMedia
import XCTest
@testable import ScreenCapture

final class LongCapturePipelineTests: XCTestCase {
    func testCaptureCadenceIsBoundedForRealtimeAnalysis() {
        XCTAssertEqual(LongCapturePipelinePolicy.framesPerSecond, 30)
        XCTAssertEqual(LongCapturePipelinePolicy.queueDepth, 3)
        XCTAssertEqual(
            LongCapturePipelinePolicy.minimumFrameInterval,
            CMTime(value: 1, timescale: 30)
        )
    }

    func testPendingFrameLimitPreventsUnboundedBacklog() {
        XCTAssertGreaterThanOrEqual(LongCapturePipelinePolicy.maximumPendingFrames, 6)
        XCTAssertLessThanOrEqual(LongCapturePipelinePolicy.maximumPendingFrames, 12)
    }
}
