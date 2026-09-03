import CoreImage
import CoreMedia
import CoreVideo
import ScreenCaptureKit

enum LongCapturePipelinePolicy {
    static let framesPerSecond: Int32 = 30
    static let queueDepth = 3
    static let maximumPendingFrames = 10
    static let minimumFrameInterval = CMTime(value: 1, timescale: framesPerSecond)
}

final class RegionCaptureStream: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    typealias FrameHandler = @Sendable (CGImage) -> Void
    typealias ErrorHandler = @Sendable (Error) -> Void

    private let filter: SCContentFilter
    private let configuration: SCStreamConfiguration
    private let frameHandler: FrameHandler
    private let errorHandler: ErrorHandler
    private let frameQueue = DispatchQueue(label: "com.nasa.ScreenCapture.long-capture.frames", qos: .userInteractive)
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let stateLock = NSLock()
    private var stream: SCStream?

    init(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        frameHandler: @escaping FrameHandler,
        errorHandler: @escaping ErrorHandler
    ) {
        self.filter = filter
        self.configuration = configuration
        self.frameHandler = frameHandler
        self.errorHandler = errorHandler
        super.init()
    }

    func start() async throws {
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameQueue)
        stateLock.withLock { self.stream = stream }
        do {
            try await stream.startCapture()
        } catch {
            clearStream(ifMatching: stream)
            throw error
        }
    }

    func stop() async {
        guard let stream = stateLock.withLock({
            let activeStream = self.stream
            self.stream = nil
            return activeStream
        }) else { return }
        try? await stream.stopCapture()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        autoreleasepool {
            guard outputType == .screen,
                  sampleBuffer.isValid,
                  let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                    sampleBuffer,
                    createIfNecessary: false
                  ) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first,
                  let statusValue = attachments[.status] as? Int,
                  SCFrameStatus(rawValue: statusValue) == .complete,
                  let pixelBuffer = sampleBuffer.imageBuffer else { return }
            let input = CIImage(cvPixelBuffer: pixelBuffer)
            guard let image = imageContext.createCGImage(input, from: input.extent) else { return }
            frameHandler(image)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        clearStream(ifMatching: stream)
        errorHandler(error)
    }

    private func clearStream(ifMatching stream: SCStream) {
        stateLock.withLock {
            if self.stream === stream { self.stream = nil }
        }
    }
}
