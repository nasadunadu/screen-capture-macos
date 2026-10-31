import AppKit
import SwiftUI

@MainActor
final class LongCaptureSession: ObservableObject {
    private typealias PendingFrame = (image: CGImage, signature: FrameSignature)

    @Published private(set) var previewSegments: [NSImage] = []
    @Published private(set) var frameCount = 0
    @Published private(set) var status = "正在初始化连续采集…"
    @Published private(set) var errorMessage: String?

    private let context: CaptureContext
    private let service: ScreenCaptureService
    private var outputSegments: [CGImage] = []
    private var previousFrame: CGImage?
    private var pendingFrames: [PendingFrame] = []
    private var outputHeight = 0
    private var fixedFooterTrim = 0
    private var lastSignature: FrameSignature?
    private var captureStream: RegionCaptureStream?
    private var startupTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var guidePanels: [EditorPanel] = []
    private var previewPanel: EditorPanel?
    private var actionPanel: EditorPanel?
    private var isRunning = false
    private var consecutiveAlignmentFailures = 0
    private var isFinishing = false
    private var isClosed = false
    var onFinish: (() -> Void)?

    init(context: CaptureContext, service: ScreenCaptureService) {
        self.context = context
        self.service = service
    }

    func start() {
        presentInterface()
        isRunning = true
        status = "正在准备高清采集…"

        startupTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                guard isRunning, !Task.isCancelled else { return }
                let stream = try await service.startRegionCaptureStream(
                    snapshot: context.snapshot,
                    selection: context.selectionRect,
                    onFrame: { [weak self] frame in
                        await self?.receive(frame)
                    },
                    onError: { [weak self] error in
                        Task { @MainActor [weak self] in self?.receiveStreamError(error) }
                    }
                )
                guard isRunning else {
                    await stream.stop()
                    return
                }
                captureStream = stream
                startupTask = nil
                status = previousFrame == nil ? "准备就绪，请在选区内向下滚动" : "请在选区内向下滚动"
            } catch {
                guard !Task.isCancelled else { return }
                receiveStreamError(error)
            }
        }
    }

    func finish() {
        guard !isClosed, !isFinishing, !outputSegments.isEmpty else {
            if outputSegments.isEmpty { cancel() }
            return
        }
        isRunning = false
        isFinishing = true
        status = "正在生成长图…"
        let stream = captureStream
        captureStream = nil
        processPendingFramesIfNeeded()
        let pendingAnalysis = analysisTask

        generationTask = Task { [weak self] in
            await stream?.stop()
            await pendingAnalysis?.value
            do {
                guard let self, !isClosed, !Task.isCancelled else { return }
                let capturedSegments = outputSegments
                let image = try await Task.detached(priority: .userInitiated) {
                    try ScrollStitcher.render(segments: capturedSegments)
                }.value
                guard !isClosed, !Task.isCancelled else { return }
                _ = try await ImageExporter.shared.performDefaultAction(image: image)
                generationTask = nil
                close()
            } catch {
                guard let self, !isClosed, !Task.isCancelled else { return }
                generationTask = nil
                isFinishing = false
                errorMessage = error.localizedDescription
                status = "生成失败"
                NSSound.beep()
            }
        }
    }

    func cancel() {
        guard !isClosed else { return }
        isRunning = false
        startupTask?.cancel()
        startupTask = nil
        generationTask?.cancel()
        generationTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        pendingFrames.removeAll()
        let stream = captureStream
        captureStream = nil
        Task { await stream?.stop() }
        close()
    }

    private func receive(_ incomingFrame: CGImage) {
        guard isRunning else { return }
        guard frameCount < 240 else {
            status = "已达到 240 帧，请完成截图"
            return
        }

        if let previousFrame {
            guard incomingFrame.width == previousFrame.width,
                  incomingFrame.height == previousFrame.height else {
                status = "采集尺寸发生异常，已跳过一帧"
                return
            }
        }
        let frame = incomingFrame

        let signature = FrameSignature(frame)
        let newestSignature = pendingFrames.last?.signature ?? lastSignature
        if let newestSignature, signature.distance(to: newestSignature) < 0.0008 { return }
        guard previousFrame != nil else {
            do {
                try append(frame, overlap: nil)
                status = "高清首帧已就绪，请向下滚动"
            } catch {
                receiveProcessingError(error)
            }
            return
        }

        if pendingFrames.count >= LongCapturePipelinePolicy.maximumPendingFrames {
            // Preserve the two earliest bridge frames closest to `previousFrame`
            // so fast scrolling never loses its overlap anchor, and compact only the tail.
            let preservedPrefix = Array(pendingFrames.prefix(2))
            let compactedTail = pendingFrames.dropFirst(2).enumerated().compactMap { index, candidate in
                index.isMultiple(of: 2) ? candidate : nil
            }
            pendingFrames = preservedPrefix + compactedTail
            status = "正在追赶快速滚动并自动衔接…"
        }
        pendingFrames.append((frame, signature))
        processPendingFramesIfNeeded()
    }

    private func processPendingFramesIfNeeded() {
        guard analysisTask == nil, !pendingFrames.isEmpty else { return }
        analysisTask = Task { @MainActor [weak self] in
            await self?.drainPendingFrames()
        }
    }

    private func drainPendingFrames() async {
        defer { analysisTask = nil }
        while !Task.isCancelled,
              isRunning || isFinishing,
              !pendingFrames.isEmpty {
            guard let previous = previousFrame else { break }
            let minimumDelta = max(6, previous.height / 160)

            var candidateImage = pendingFrames.removeFirst().image
            var alignment: FrameAlignment?

            if pendingFrames.count >= 2 {
                let lookaheadImage = pendingFrames[0].image
                let stepTwoAlignment = await Task.detached(priority: .userInitiated) { [previous, lookaheadImage] in
                    ScrollStitcher.alignment(previous: previous, next: lookaheadImage)
                }.value
                guard !Task.isCancelled, isRunning || isFinishing else { return }
                if let stepTwoAlignment,
                   stepTwoAlignment.scrollDelta >= minimumDelta,
                   stepTwoAlignment.confidence >= 0.88 {
                    _ = pendingFrames.removeFirst()
                    candidateImage = lookaheadImage
                    alignment = stepTwoAlignment
                }
            }

            if alignment == nil {
                let currentCandidateImage = candidateImage
                alignment = await Task.detached(priority: .userInitiated) { [previous, currentCandidateImage] in
                    ScrollStitcher.alignment(previous: previous, next: currentCandidateImage)
                }.value
                guard !Task.isCancelled, isRunning || isFinishing else { return }
            }

            guard let alignment else {
                consecutiveAlignmentFailures += 1
                status = consecutiveAlignmentFailures >= 3
                    ? "跨度过大，正在自动寻找可恢复的重叠位置…"
                    : "正在识别快速滚动的衔接位置…"
                continue
            }

            guard alignment.scrollDelta >= minimumDelta else {
                // Keep `lastSignature` anchored to `previousFrame` so slow continuous
                // scrolling accumulates delta instead of creeping the signature forward.
                continue
            }
            do {
                try append(
                    candidateImage,
                    overlap: alignment.overlap,
                    trailingTrim: alignment.trailingTrim
                )
                consecutiveAlignmentFailures = 0
                status = pendingFrames.isEmpty
                    ? "已拼接 \(frameCount) 帧，继续滚动或完成"
                    : "正在追赶快速滚动，已拼接 \(frameCount) 帧"
            } catch {
                receiveProcessingError(error)
            }
        }
    }

    private func receiveStreamError(_ error: Error) {
        guard isRunning else { return }
        isRunning = false
        captureStream = nil
        errorMessage = error.localizedDescription
        status = "连续采集已停止"
        NSSound.beep()
    }

    private func append(
        _ image: CGImage,
        overlap: Int?,
        trailingTrim: Int = 0
    ) throws {
        let segment: CGImage
        if let overlap {
            let maxAllowedTrim = max(0, overlap - 1)
            let desiredTrim = min(max(fixedFooterTrim, trailingTrim), maxAllowedTrim)
            if desiredTrim > fixedFooterTrim {
                let trimmed = trimOutputTail(by: desiredTrim - fixedFooterTrim)
                fixedFooterTrim += trimmed
            }
            let effectiveTrailingTrim = min(fixedFooterTrim, maxAllowedTrim)
            segment = try ScrollStitcher.newContentSegment(
                from: image,
                overlap: overlap,
                trailingTrim: effectiveTrailingTrim
            )
        } else {
            segment = image
        }
        try ScrollStitcher.validateOutputSize(
            width: segment.width,
            height: outputHeight + segment.height
        )
        outputSegments.append(segment)
        outputHeight += segment.height
        previousFrame = image
        lastSignature = FrameSignature(image)
        frameCount += 1
        errorMessage = nil
        if previewPanel != nil {
            previewSegments.append(NSImage(cgImage: segment, size: .zero))
        }
    }

    private func trimOutputTail(by deltaTrim: Int) -> Int {
        guard deltaTrim > 0, !outputSegments.isEmpty else { return 0 }
        var remaining = deltaTrim
        var trimmedTotal = 0
        while remaining > 0, let last = outputSegments.last {
            let minKeepHeight = outputSegments.count == 1 ? max(1, last.height / 2) : 0
            let availableToTrim = max(0, last.height - minKeepHeight)
            guard availableToTrim > 0 else { break }

            if remaining >= last.height, outputSegments.count > 1 {
                outputSegments.removeLast()
                outputHeight -= last.height
                trimmedTotal += last.height
                remaining -= last.height
                if !previewSegments.isEmpty {
                    previewSegments.removeLast()
                }
            } else {
                let cut = min(remaining, availableToTrim)
                let newHeight = last.height - cut
                guard newHeight > 0,
                      let cropped = last.cropping(to: CGRect(
                          x: 0,
                          y: 0,
                          width: last.width,
                          height: newHeight
                      )) else { break }
                outputSegments[outputSegments.count - 1] = cropped
                outputHeight -= cut
                trimmedTotal += cut
                remaining -= cut
                if previewSegments.count == outputSegments.count {
                    previewSegments[previewSegments.count - 1] = NSImage(cgImage: cropped, size: .zero)
                }
                break
            }
        }
        return trimmedTotal
    }

    private func receiveProcessingError(_ error: Error) {
        errorMessage = error.localizedDescription
        status = "当前帧已跳过，正在自动继续衔接"
        NSSound.beep()
    }

    private func presentInterface() {
        presentGuide()
        presentPreview()
        presentActionBar()
    }

    private func presentGuide() {
        let screen = context.snapshot.screen
        let screenFrame = screen.frame
        let selection = context.globalFrame.intersection(screenFrame)
        let sizeText = "\(Int(context.selectionRect.width)) × \(Int(context.selectionRect.height))"
        let topHeight = max(0, screenFrame.maxY - selection.maxY)
        let bottomHeight = max(0, selection.minY - screenFrame.minY)
        guidePanels = LongCaptureLayout.maskDescriptors(
            screenFrame: screenFrame,
            selectionFrame: selection
        ).map { descriptor in
            let label: String?
            if descriptor.innerEdge == .top, topHeight >= 34 {
                label = sizeText
            } else if descriptor.innerEdge == .bottom, topHeight < 34, bottomHeight >= 34 {
                label = sizeText
            } else {
                label = nil
            }
            let panel = makePanel(frame: descriptor.frame, ignoresMouseEvents: true)
            panel.contentView = LongCaptureMaskView(
                frame: CGRect(origin: .zero, size: descriptor.frame.size),
                innerEdge: descriptor.innerEdge,
                sizeText: label
            )
            panel.orderFrontRegardless()
            return panel
        }
    }

    private func presentPreview() {
        let visible = context.snapshot.screen.visibleFrame
        guard let frame = LongCaptureLayout.previewFrame(
            visibleFrame: visible,
            selectionFrame: context.globalFrame
        ) else {
            previewPanel = nil
            return
        }
        let panel = makePanel(
            frame: frame,
            ignoresMouseEvents: true
        )
        panel.contentView = NSHostingView(rootView: LongCapturePreviewView(session: self))
        panel.orderFrontRegardless()
        previewPanel = panel
    }

    private func presentActionBar() {
        let visible = context.snapshot.screen.visibleFrame
        let height: CGFloat = 62
        let preferredWidth = min(max(280, context.globalFrame.width * 0.68), min(460, visible.width - 16))
        let belowY = context.globalFrame.minY - height - 8
        let aboveY = context.globalFrame.maxY + 8
        let rightSpace = visible.maxX - context.globalFrame.maxX - 8
        let leftSpace = context.globalFrame.minX - visible.minX - 8
        let frame: CGRect
        if belowY >= visible.minY {
            let x = min(
                max(context.globalFrame.midX - preferredWidth / 2, visible.minX + 8),
                visible.maxX - preferredWidth - 8
            )
            frame = CGRect(x: x, y: belowY, width: preferredWidth, height: height)
        } else if aboveY + height <= visible.maxY {
            let x = min(
                max(context.globalFrame.midX - preferredWidth / 2, visible.minX + 8),
                visible.maxX - preferredWidth - 8
            )
            frame = CGRect(x: x, y: aboveY, width: preferredWidth, height: height)
        } else if rightSpace >= 180 {
            let width = min(preferredWidth, rightSpace)
            frame = CGRect(
                x: context.globalFrame.maxX + 8,
                y: max(visible.minY + 8, context.globalFrame.minY),
                width: width,
                height: height
            )
        } else if leftSpace >= 180 {
            let width = min(preferredWidth, leftSpace)
            frame = CGRect(
                x: context.globalFrame.minX - width - 8,
                y: max(visible.minY + 8, context.globalFrame.minY),
                width: width,
                height: height
            )
        } else {
            let compactWidth = min(320, max(120, context.globalFrame.width - 16))
            frame = CGRect(
                x: context.globalFrame.maxX - compactWidth - 8,
                y: context.globalFrame.minY + 8,
                width: compactWidth,
                height: height
            )
        }

        let panel = makePanel(frame: frame, ignoresMouseEvents: false)
        panel.contentView = NSHostingView(rootView: LongCaptureActionBarView(session: self))
        panel.orderFrontRegardless()
        actionPanel = panel
    }

    private func makePanel(frame: CGRect, ignoresMouseEvents: Bool) -> EditorPanel {
        let panel = EditorPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        startupTask?.cancel()
        startupTask = nil
        analysisTask?.cancel()
        analysisTask = nil
        let guidesToRetire = guidePanels
        let previewToRetire = previewPanel
        let actionToRetire = actionPanel
        guidePanels.removeAll()
        previewPanel = nil
        actionPanel = nil
        EditorPanel.retire(guidesToRetire)
        EditorPanel.retire(previewToRetire)
        EditorPanel.retire(actionToRetire)
        outputSegments.removeAll()
        previousFrame = nil
        pendingFrames.removeAll()
        outputHeight = 0
        fixedFooterTrim = 0
        consecutiveAlignmentFailures = 0
        previewSegments.removeAll()
        frameCount = 0
        onFinish?()
    }
}
