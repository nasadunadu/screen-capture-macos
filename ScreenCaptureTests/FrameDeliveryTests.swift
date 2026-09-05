import CoreGraphics
import XCTest
@testable import ScreenCapture

private actor DeliveryBarrier {
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        released = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

final class FrameDeliveryTests: XCTestCase {
    func testStalledConsumerBoundsFramesBeforeImageConversion() async throws {
        let barrier = DeliveryBarrier()
        let completed = expectation(description: "Accepted frames finish delivery")
        completed.expectedFulfillmentCount = LongCapturePipelinePolicy.maximumDeliveringFrames
        // The old implementation delivers all 200 frames; report the bound assertion instead.
        completed.assertForOverFulfill = false
        let delivery = BoundedFrameDelivery { _ in
            await barrier.wait()
            completed.fulfill()
        }
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 16,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        var converted = 0
        for _ in 0..<200 {
            delivery.offer {
                converted += 1
                return image
            }
        }
        XCTAssertEqual(converted, LongCapturePipelinePolicy.maximumDeliveringFrames)
        await barrier.release()
        await fulfillment(of: [completed], timeout: 5)
    }

    func testFailedConversionDoesNotExhaustDeliverySlots() {
        let delivery = BoundedFrameDelivery { _ in }
        var conversions = 0
        for _ in 0..<20 {
            XCTAssertFalse(delivery.offer {
                conversions += 1
                return nil
            })
        }
        XCTAssertEqual(conversions, 20)
    }
}
