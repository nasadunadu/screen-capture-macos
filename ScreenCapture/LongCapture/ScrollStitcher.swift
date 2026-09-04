import CoreGraphics
import Foundation
import Vision

enum StitchError: LocalizedError {
    case mismatchedFrames
    case insufficientOverlap(frame: Int)
    case outputTooTall
    case outputTooLarge
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .mismatchedFrames: "长截图帧的尺寸不一致。"
        case let .insufficientOverlap(frame): "第 \(frame) 帧与上一帧没有找到可靠的重叠区域。请减慢滚动后重试。"
        case .outputTooTall: "长截图超过当前版本支持的最大高度。"
        case .outputTooLarge: "长截图像素量过大，继续生成可能耗尽内存。请缩小选区宽度后重试。"
        case .renderingFailed: "无法生成拼接后的长截图。"
        }
    }
}

struct StitchAnalysis {
    let overlaps: [Int]
    let outputHeight: Int
}

struct FrameAlignment {
    enum Source {
        case visionBands
        case visionFullFrame
        case pixelFallback
    }

    let overlap: Int
    let scrollDelta: Int
    let trailingTrim: Int
    let confidence: Float
    let source: Source
}

enum ScrollStitcher {
    static let maximumOutputHeight = 100_000
    // Rendering needs both the accepted strips and a final 4-byte-per-pixel
    // canvas at the same time. Keep the expected pair below roughly 512 MiB.
    static let maximumOutputPixels = 60_000_000

    static func validateOutputSize(width: Int, height: Int) throws {
        guard width > 0, height > 0 else { throw StitchError.renderingFailed }
        guard height <= maximumOutputHeight else { throw StitchError.outputTooTall }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixels <= maximumOutputPixels else { throw StitchError.outputTooLarge }
    }

    static func alignment(previous: CGImage, next: CGImage) -> FrameAlignment? {
        guard previous.width == next.width,
              previous.height == next.height,
              previous.width > 0,
              previous.height > 0 else { return nil }

        if FrameSignature(previous).distance(to: FrameSignature(next)) < 0.001 {
            return FrameAlignment(
                overlap: previous.height,
                scrollDelta: 0,
                trailingTrim: 0,
                confidence: 1,
                source: .pixelFallback
            )
        }

        let previousSample = GrayFrame(previous)
        let nextSample = GrayFrame(next)
        guard previousSample.detailScore >= 0.0005,
              nextSample.detailScore >= 0.0005 else { return nil }
        let ordinaryMatch = bestOverlap(previous: previousSample, next: nextSample)
        var selectedEdgeMatch: EdgeAwareOverlap?
        let match: (rows: Int, score: Double)
        if ordinaryMatch.score >= 0.16,
           let insetMatch = fixedEdgeAwareOverlapDetails(
               previous: previousSample,
               next: nextSample
           ),
           insetMatch.score + 0.008 < ordinaryMatch.score {
            selectedEdgeMatch = insetMatch
            match = (insetMatch.rows, insetMatch.score)
        } else {
            match = ordinaryMatch
        }
        if match.score < 0.16 {
            return pixelAlignment(
                match: match,
                frameHeight: previous.height,
                sampleHeight: nextSample.height,
                trailingSampleTrim: selectedEdgeMatch?.trailingInset ?? 0
            )
        }
        if let vision = visionAlignment(previous: previous, next: next) {
            let sampledOverlap = min(
                nextSample.height,
                max(1, Int(round(
                    CGFloat(vision.overlap) * CGFloat(nextSample.height) / CGFloat(previous.height)
                )))
            )
            let visionScore = overlapScore(
                previous: previousSample,
                next: nextSample,
                overlap: sampledOverlap
            )
            if visionScore < 0.26 {
                return applyingTrailingTrim(
                    selectedEdgeMatch?.trailingInset ?? 0,
                    sampleHeight: nextSample.height,
                    to: vision,
                    frameHeight: previous.height
                )
            }
        }

        guard match.score < 0.20 else { return nil }
        return pixelAlignment(
            match: match,
            frameHeight: previous.height,
            sampleHeight: nextSample.height,
            trailingSampleTrim: selectedEdgeMatch?.trailingInset ?? 0
        )
    }

    private static func pixelAlignment(
        match: (rows: Int, score: Double),
        frameHeight: Int,
        sampleHeight: Int,
        trailingSampleTrim: Int
    ) -> FrameAlignment {
        let pixelOverlap = min(
            frameHeight,
            max(0, Int(round(CGFloat(match.rows) * CGFloat(frameHeight) / CGFloat(sampleHeight))))
        )
        return FrameAlignment(
            overlap: pixelOverlap,
            scrollDelta: frameHeight - pixelOverlap,
            trailingTrim: scaledTrim(
                trailingSampleTrim,
                sampleHeight: sampleHeight,
                frameHeight: frameHeight
            ),
            confidence: Float(max(0, 1 - match.score)),
            source: .pixelFallback
        )
    }

    private static func applyingTrailingTrim(
        _ sampleTrim: Int,
        sampleHeight: Int,
        to alignment: FrameAlignment,
        frameHeight: Int
    ) -> FrameAlignment {
        FrameAlignment(
            overlap: alignment.overlap,
            scrollDelta: alignment.scrollDelta,
            trailingTrim: scaledTrim(
                sampleTrim,
                sampleHeight: sampleHeight,
                frameHeight: frameHeight
            ),
            confidence: alignment.confidence,
            source: alignment.source
        )
    }

    private static func scaledTrim(
        _ sampleTrim: Int,
        sampleHeight: Int,
        frameHeight: Int
    ) -> Int {
        guard sampleTrim > 0, sampleHeight > 0 else { return 0 }
        return min(
            frameHeight / 3,
            max(0, Int((CGFloat(sampleTrim) * CGFloat(frameHeight) / CGFloat(sampleHeight)).rounded()))
        )
    }

    static func analyze(_ frames: [CGImage]) throws -> StitchAnalysis {
        guard let first = frames.first else { return StitchAnalysis(overlaps: [], outputHeight: 0) }
        guard frames.allSatisfy({ $0.width == first.width && $0.height == first.height }) else {
            throw StitchError.mismatchedFrames
        }
        try validateOutputSize(width: first.width, height: first.height)
        guard frames.count > 1 else {
            return StitchAnalysis(overlaps: [], outputHeight: first.height)
        }

        var overlaps: [Int] = []
        var outputHeight = first.height
        for index in 1..<frames.count {
            guard let match = alignment(previous: frames[index - 1], next: frames[index]) else {
                throw StitchError.insufficientOverlap(frame: index + 1)
            }
            overlaps.append(match.overlap)
            outputHeight += match.scrollDelta
            try validateOutputSize(width: first.width, height: outputHeight)
        }
        return StitchAnalysis(overlaps: overlaps, outputHeight: outputHeight)
    }

    static func stitch(_ frames: [CGImage]) throws -> CGImage {
        let analysis = try analyze(frames)
        return try stitch(frames, overlaps: analysis.overlaps)
    }

    static func stitch(_ frames: [CGImage], overlaps: [Int]) throws -> CGImage {
        guard let first = frames.first else { throw StitchError.renderingFailed }
        guard frames.allSatisfy({ $0.width == first.width && $0.height == first.height }),
              overlaps.count == max(0, frames.count - 1) else {
            throw StitchError.mismatchedFrames
        }

        var segments = [first]
        for index in 1..<frames.count {
            let overlap = overlaps[index - 1]
            guard overlap >= 0, overlap <= frames[index].height else { throw StitchError.renderingFailed }
            if overlap < frames[index].height {
                segments.append(try newContentSegment(from: frames[index], overlap: overlap))
            }
        }
        return try render(segments: segments)
    }

    static func newContentSegment(
        from frame: CGImage,
        overlap: Int,
        trailingTrim: Int = 0
    ) throws -> CGImage {
        let segmentHeight = frame.height - overlap
        let startY = overlap - trailingTrim
        guard overlap >= 0,
              overlap < frame.height,
              trailingTrim >= 0,
              startY >= 0,
              startY + segmentHeight <= frame.height,
              segmentHeight > 0,
              let cropped = frame.cropping(to: CGRect(
                  x: 0,
                  y: startY,
                  width: frame.width,
                  height: segmentHeight
              )),
              let copied = copiedImage(cropped) else {
            throw StitchError.renderingFailed
        }
        return copied
    }

    static func render(segments: [CGImage]) throws -> CGImage {
        guard let first = segments.first,
              segments.allSatisfy({ $0.width == first.width }) else {
            throw StitchError.mismatchedFrames
        }

        let outputHeight = try segments.reduce(0) { height, segment in
            let nextHeight = height + segment.height
            try validateOutputSize(width: first.width, height: nextHeight)
            return nextHeight
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: first.width,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw StitchError.renderingFailed }

        var consumedHeight = 0
        for segment in segments {
            context.draw(
                segment,
                in: CGRect(
                    x: 0,
                    y: outputHeight - consumedHeight - segment.height,
                    width: segment.width,
                    height: segment.height
                )
            )
            consumedHeight += segment.height
        }
        guard let output = context.makeImage() else { throw StitchError.renderingFailed }
        return output
    }

    private static func visionAlignment(previous: CGImage, next: CGImage) -> FrameAlignment? {
        let maximumAnalysisWidth = 900
        let analysisWidth = min(maximumAnalysisWidth, previous.width)
        let scale = CGFloat(analysisWidth) / CGFloat(previous.width)
        let analysisHeight = max(1, Int((CGFloat(previous.height) * scale).rounded()))
        guard let previousAnalysis = resized(previous, width: analysisWidth, height: analysisHeight),
              let nextAnalysis = resized(next, width: analysisWidth, height: analysisHeight) else { return nil }

        let translations = comparisonBands(width: analysisWidth, height: analysisHeight).compactMap { rect -> VisionTranslation? in
            guard let previousBand = previousAnalysis.cropping(to: rect),
                  let nextBand = nextAnalysis.cropping(to: rect),
                  let translation = translation(current: nextBand, targetedTo: previousBand),
                  isPlausible(translation, frameHeight: CGFloat(analysisHeight)) else { return nil }
            return translation
        }

        if translations.count >= 4,
           let group = bestAgreement(in: translations, minimumCount: 4),
           let average = average(group) {
            return frameAlignment(
                translation: average,
                source: .visionBands,
                frameHeight: previous.height,
                analysisScale: scale
            )
        }

        guard let fullFrame = translation(current: nextAnalysis, targetedTo: previousAnalysis),
              fullFrame.confidence >= 0.90,
              isPlausible(fullFrame, frameHeight: CGFloat(analysisHeight)) else { return nil }
        return frameAlignment(
            translation: fullFrame,
            source: .visionFullFrame,
            frameHeight: previous.height,
            analysisScale: scale
        )
    }

    private static func frameAlignment(
        translation: VisionTranslation,
        source: FrameAlignment.Source,
        frameHeight: Int,
        analysisScale: CGFloat
    ) -> FrameAlignment? {
        guard analysisScale > 0 else { return nil }
        let delta = Int((translation.y / analysisScale).rounded())
        guard delta <= Int(CGFloat(frameHeight) * 0.94) else { return nil }
        return FrameAlignment(
            overlap: max(0, frameHeight - delta),
            scrollDelta: delta,
            trailingTrim: 0,
            confidence: translation.confidence,
            source: source
        )
    }

    private static func comparisonBands(width: Int, height: Int) -> [CGRect] {
        let count = 5
        let bandHeight = min(height, max(80, height / 3))
        let maximumY = max(0, height - bandHeight)
        guard maximumY > 0 else {
            return [CGRect(x: 0, y: 0, width: width, height: bandHeight)]
        }
        return (0..<count).map { index in
            let y = Int((CGFloat(maximumY) * CGFloat(index) / CGFloat(count - 1)).rounded())
            return CGRect(x: 0, y: y, width: width, height: bandHeight)
        }
    }

    private static func translation(current: CGImage, targetedTo previous: CGImage) -> VisionTranslation? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previous)
        let handler = VNImageRequestHandler(cgImage: current, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else { return nil }
        return VisionTranslation(
            x: observation.alignmentTransform.tx,
            y: observation.alignmentTransform.ty,
            confidence: observation.confidence
        )
    }

    private static func isPlausible(_ translation: VisionTranslation, frameHeight: CGFloat) -> Bool {
        abs(translation.x) <= 4
            && translation.y >= 0
            && translation.y <= frameHeight * 0.94
            && translation.confidence >= 0.30
    }

    private static func bestAgreement(
        in translations: [VisionTranslation],
        minimumCount: Int
    ) -> [VisionTranslation]? {
        guard minimumCount > 0 else { return nil }
        let tolerance: CGFloat = 4
        let best = translations.reduce(into: [VisionTranslation]()) { currentBest, candidate in
            let group = translations.filter { abs($0.y - candidate.y) <= tolerance }
            if group.count > currentBest.count { currentBest = group }
        }
        return best.count >= minimumCount ? best : nil
    }

    private static func average(_ translations: [VisionTranslation]) -> VisionTranslation? {
        guard !translations.isEmpty else { return nil }
        let count = CGFloat(translations.count)
        return VisionTranslation(
            x: translations.reduce(0) { $0 + $1.x } / count,
            y: translations.reduce(0) { $0 + $1.y } / count,
            confidence: translations.reduce(0) { $0 + $1.confidence } / Float(translations.count)
        )
    }

    private static func resized(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func copiedImage(_ image: CGImage) -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private static func bestOverlap(previous: GrayFrame, next: GrayFrame) -> (rows: Int, score: Double) {
        if previous.width == next.width,
           previous.height == next.height,
           previous.bytes == next.bytes {
            return (previous.height, 0)
        }

        let height = min(previous.height, next.height)
        let minOverlap = max(12, height / 16)
        let maxOverlap = max(minOverlap, height - 6)
        var bestRows = minOverlap
        var bestScore = Double.greatestFiniteMagnitude

        // A coarse scan followed by an exact local refinement preserves the
        // selected row while avoiding hundreds of expensive full comparisons.
        let coarseStep = max(1, height / 120)
        var overlap = minOverlap
        while overlap <= maxOverlap {
            let raw = overlapScore(previous: previous, next: next, overlap: overlap)
            let preferenceForLargerOverlap = Double(height - overlap) / Double(height) * 0.003
            let score = raw + preferenceForLargerOverlap
            if score < bestScore {
                bestScore = score
                bestRows = overlap
            }
            overlap += coarseStep
        }
        if (maxOverlap - minOverlap).isMultiple(of: coarseStep) == false {
            let raw = overlapScore(previous: previous, next: next, overlap: maxOverlap)
            let score = raw + Double(height - maxOverlap) / Double(height) * 0.003
            if score < bestScore {
                bestScore = score
                bestRows = maxOverlap
            }
        }

        let refinement = max(minOverlap, bestRows - coarseStep)...min(maxOverlap, bestRows + coarseStep)
        for overlap in refinement {
            let raw = overlapScore(previous: previous, next: next, overlap: overlap)
            let preferenceForLargerOverlap = Double(height - overlap) / Double(height) * 0.003
            let score = raw + preferenceForLargerOverlap
            if score < bestScore {
                bestScore = score
                bestRows = overlap
            }
        }
        return (bestRows, bestScore)
    }

    static func fixedEdgeAwareOverlap(
        previous: GrayFrame,
        next: GrayFrame
    ) -> (rows: Int, score: Double)? {
        guard let match = fixedEdgeAwareOverlapDetails(previous: previous, next: next) else {
            return nil
        }
        return (match.rows, match.score)
    }

    private static func fixedEdgeAwareOverlapDetails(
        previous: GrayFrame,
        next: GrayFrame
    ) -> EdgeAwareOverlap? {
        let height = min(previous.height, next.height)
        let minOverlap = max(12, height / 16)
        let maxOverlap = max(minOverlap, height - 6)
        let minimumComparedRows = max(24, height / 12)
        let maximumInset = min(height / 3, max(0, maxOverlap - minimumComparedRows))
        guard maximumInset >= 4 else { return nil }

        let overlapStep = max(1, height / 96)
        let insetStep = max(2, height / 24)
        let oneSidedInsets = stride(
            from: insetStep,
            through: maximumInset,
            by: insetStep
        )
        let pairedMaximumInset = min(maximumInset, max(0, (maxOverlap - minimumComparedRows) / 2))
        let pairedInsets = pairedMaximumInset >= insetStep
            ? Array(stride(from: insetStep, through: pairedMaximumInset, by: insetStep))
            : []
        var profiles = oneSidedInsets.flatMap { inset in
            [(leading: inset, trailing: 0), (leading: 0, trailing: inset)]
        }
        // Many modern apps keep both a navigation/header area and a composer or
        // action bar fixed. Compare only their moving centre instead of letting
        // two stationary edges defeat the scroll match.
        profiles.append(contentsOf: pairedInsets.map { (leading: $0, trailing: $0) })

        var bestRows = minOverlap
        var bestProfile = (leading: 0, trailing: 0)
        var bestScore = Double.greatestFiniteMagnitude

        for profile in profiles {
            let totalInset = profile.leading + profile.trailing
            let firstOverlap = max(minOverlap, totalInset + minimumComparedRows)
            var overlap = firstOverlap
            while overlap <= maxOverlap {
                let raw = overlapScore(
                    previous: previous,
                    next: next,
                    overlap: overlap,
                    leadingInset: profile.leading,
                    trailingInset: profile.trailing
                )
                let scrollPreference = Double(height - overlap) / Double(height) * 0.003
                let insetPenalty = Double(totalInset) / Double(height) * 0.008
                let score = raw + scrollPreference + insetPenalty
                if score < bestScore {
                    bestScore = score
                    bestRows = overlap
                    bestProfile = profile
                }
                overlap += overlapStep
            }
        }

        guard bestScore.isFinite else { return nil }
        let bestTotalInset = bestProfile.leading + bestProfile.trailing
        let refinedOverlaps = max(
            max(minOverlap, bestTotalInset + minimumComparedRows),
            bestRows - overlapStep
        )...min(maxOverlap, bestRows + overlapStep)
        for candidateOverlap in refinedOverlaps {
            let raw = overlapScore(
                previous: previous,
                next: next,
                overlap: candidateOverlap,
                leadingInset: bestProfile.leading,
                trailingInset: bestProfile.trailing
            )
            let scrollPreference = Double(height - candidateOverlap) / Double(height) * 0.003
            let insetPenalty = Double(bestTotalInset) / Double(height) * 0.008
            let score = raw + scrollPreference + insetPenalty
            if score < bestScore {
                bestScore = score
                bestRows = candidateOverlap
            }
        }
        return EdgeAwareOverlap(
            rows: bestRows,
            score: bestScore,
            leadingInset: bestProfile.leading,
            trailingInset: bestProfile.trailing
        )
    }

    private static func overlapScore(
        previous: GrayFrame,
        next: GrayFrame,
        overlap: Int,
        leadingInset: Int = 0,
        trailingInset: Int = 0
    ) -> Double {
        let width = min(previous.width, next.width)
        guard overlap > 0,
              overlap <= min(previous.height, next.height),
              leadingInset >= 0,
              trailingInset >= 0,
              leadingInset + trailingInset < overlap,
              width > 2 else { return .greatestFiniteMagnitude }

        let comparedRows = overlap - leadingInset - trailingInset
        let comparisonEnd = overlap - trailingInset
        let yStep = max(1, comparedRows / 56)
        var pixelDifference = 0.0
        var edgeDifference = 0.0
        var edgeEnergy = 0.0
        var pixelCount = 0
        var y = leadingInset
        while y < comparisonEnd {
            let previousY = previous.height - overlap + y
            let nextY = y
            var x = 2
            while x < width - 2 {
                let a = Int(previous[x, previousY])
                let b = Int(next[x, nextY])
                pixelDifference += Double(abs(a - b)) / 255.0

                let horizontalA = abs(a - Int(previous[x - 1, previousY]))
                let horizontalB = abs(b - Int(next[x - 1, nextY]))
                edgeDifference += Double(abs(horizontalA - horizontalB))
                edgeEnergy += Double(max(horizontalA, horizontalB))
                if y > leadingInset {
                    let verticalA = abs(a - Int(previous[x, previousY - min(yStep, previousY)]))
                    let verticalB = abs(b - Int(next[x, nextY - min(yStep, nextY)]))
                    edgeDifference += Double(abs(verticalA - verticalB))
                    edgeEnergy += Double(max(verticalA, verticalB))
                }
                pixelCount += 1
                x += 3
            }
            y += yStep
        }
        guard pixelCount > 0, edgeEnergy > 0 else { return .greatestFiniteMagnitude }
        let luminanceScore = pixelDifference / Double(pixelCount)
        let structureScore = min(1, edgeDifference / edgeEnergy)
        return luminanceScore * 0.25 + structureScore * 0.75
    }
}

private struct EdgeAwareOverlap {
    let rows: Int
    let score: Double
    let leadingInset: Int
    let trailingInset: Int
}

private struct VisionTranslation {
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
}

struct FrameSignature {
    private let values: [UInt8]

    init(_ image: CGImage) {
        let width = 16
        let height = 16
        var data = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        data.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: space,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        values = data
    }

    func distance(to other: FrameSignature) -> Double {
        guard values.count == other.values.count, !values.isEmpty else { return 1 }
        let total = zip(values, other.values).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(values.count * 255)
    }
}

struct GrayFrame {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(width > 0 && height > 0 && bytes.count == width * height)
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init(_ image: CGImage) {
        let targetWidth = min(56, image.width)
        let targetHeight = min(520, image.height)
        var storage = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        storage.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: targetWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
        width = targetWidth
        height = targetHeight
        bytes = storage
    }

    subscript(x: Int, y: Int) -> UInt8 { bytes[y * width + x] }

    var detailScore: Double {
        guard width > 1, height > 1 else { return 0 }
        var total = 0
        var count = 0
        for y in 1..<height {
            for x in 1..<width {
                total += abs(Int(self[x, y]) - Int(self[x - 1, y]))
                total += abs(Int(self[x, y]) - Int(self[x, y - 1]))
                count += 2
            }
        }
        guard count > 0 else { return 0 }
        return Double(total) / Double(count * 255)
    }
}
