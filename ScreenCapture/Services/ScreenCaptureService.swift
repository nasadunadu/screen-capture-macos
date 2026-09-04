import AppKit
import CoreMedia
import CoreVideo
import CoreGraphics
import ScreenCaptureKit

struct WindowCandidate {
    let window: SCWindow
    let globalFrame: CGRect
    let localFrame: CGRect
    let title: String
}

struct DisplaySnapshot {
    let screen: NSScreen
    let display: SCDisplay
    let ownApplication: SCRunningApplication?
    let displayBounds: CGRect
    let image: CGImage
    let windows: [WindowCandidate]
}

struct ScreenDisplayCandidate: Equatable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
}

enum ScreenDisplayMatcher {
    static func selectDisplayID(
        preferredID: CGDirectDisplayID?,
        preferredFrame: CGRect,
        currentScreens: [ScreenDisplayCandidate],
        availableDisplayIDs: [CGDirectDisplayID]
    ) -> CGDirectDisplayID? {
        guard !availableDisplayIDs.isEmpty else { return nil }
        let available = Set(availableDisplayIDs)
        if let preferredID, available.contains(preferredID) { return preferredID }

        let matchingScreens = currentScreens.filter { available.contains($0.displayID) }
        let bestOverlap = matchingScreens.max { left, right in
            overlapArea(left.frame, preferredFrame) < overlapArea(right.frame, preferredFrame)
        }
        if let bestOverlap, overlapArea(bestOverlap.frame, preferredFrame) > 0 {
            return bestOverlap.displayID
        }
        if let currentMainDisplay = matchingScreens.first?.displayID {
            return currentMainDisplay
        }
        return availableDisplayIDs.first
    }

    private static func overlapArea(_ left: CGRect, _ right: CGRect) -> CGFloat {
        guard left.isFinite, right.isFinite else { return 0 }
        let intersection = left.intersection(right)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }
}

enum CaptureServiceError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "需要屏幕录制权限才能截图。请在系统设置的隐私与安全性中允许 Screen Capture。"
        case .displayUnavailable: "找不到光标所在的显示器。"
        case .captureFailed: "系统没有返回可用的截图。"
        }
    }

    var needsPermissionRecovery: Bool {
        if case .permissionDenied = self { return true }
        return false
    }
}

@MainActor
final class ScreenCaptureService {
    func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
    }

    func captureDisplay(on requestedScreen: NSScreen? = nil, includeWindows: Bool = true) async throws -> DisplaySnapshot {
        if !ScreenCapturePermission.isGranted {
            _ = ScreenCapturePermission.request()
        }
        guard let preferredScreen = requestedScreen ?? screenUnderPointer() else {
            throw CaptureServiceError.displayUnavailable
        }
        let preferredDisplayID = displayID(for: preferredScreen)

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            ScreenCapturePermission.markAccessConfirmed()
        } catch {
            if !ScreenCapturePermission.isGranted {
                throw CaptureServiceError.permissionDenied
            }
            throw error
        }
        let currentScreens = NSScreen.screens.compactMap { screen -> ScreenDisplayCandidate? in
            guard let displayID = displayID(for: screen) else { return nil }
            return ScreenDisplayCandidate(displayID: displayID, frame: screen.frame)
        }
        guard let displayID = ScreenDisplayMatcher.selectDisplayID(
            preferredID: preferredDisplayID,
            preferredFrame: preferredScreen.frame,
            currentScreens: currentScreens,
            availableDisplayIDs: content.displays.map(\.displayID)
        ),
        let display = content.displays.first(where: { $0.displayID == displayID }),
        let screen = NSScreen.screens.first(where: { self.displayID(for: $0) == displayID })
            ?? NSScreen.screens.max(by: {
                $0.frame.intersection(preferredScreen.frame).area
                    < $1.frame.intersection(preferredScreen.frame).area
            })
            ?? NSScreen.main else {
            throw CaptureServiceError.displayUnavailable
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownApplication = content.applications.first { $0.bundleIdentifier == ownBundleID }
        let ownWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == ownBundleID }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let configuration = SCStreamConfiguration()
        let scale = nativeScale(for: screen, displayID: displayID)
        let pixelSize = CaptureGeometry.nativePixelSize(logicalSize: screen.frame.size, scale: scale)
        configuration.width = Int(pixelSize.width)
        configuration.height = Int(pixelSize.height)
        configuration.showsCursor = AppSettings.shared.captureCursor
        configuration.shouldBeOpaque = false
        applyHighQualitySettings(to: configuration)

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let displayBounds = CGDisplayBounds(displayID)
        let candidates: [WindowCandidate]
        if includeWindows {
            candidates = content.windows.compactMap { window in
                guard window.isOnScreen,
                      window.windowID != 0,
                      window.owningApplication?.bundleIdentifier != ownBundleID,
                      window.frame.width >= 40,
                      window.frame.height >= 30,
                      window.frame.intersects(displayBounds) else { return nil }
                let global = CaptureGeometry.appKitFrame(
                    for: window.frame,
                    displayBounds: displayBounds,
                    screenFrame: screen.frame
                )
                return WindowCandidate(
                    window: window,
                    globalFrame: global,
                    localFrame: CaptureGeometry.localFrame(globalFrame: global, on: screen),
                    title: window.title ?? window.owningApplication?.applicationName ?? "窗口"
                )
            }
        } else {
            candidates = []
        }
        return DisplaySnapshot(
            screen: screen,
            display: display,
            ownApplication: ownApplication,
            displayBounds: displayBounds,
            image: image,
            windows: candidates
        )
    }

    func captureWindow(_ candidate: WindowCandidate) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: candidate.window)
        let configuration = SCStreamConfiguration()
        let screen = NSScreen.screens.first { $0.frame.intersects(candidate.globalFrame) } ?? NSScreen.main
        let scale = screen.map { nativeScale(for: $0) } ?? 2
        let pixelSize = CaptureGeometry.nativePixelSize(logicalSize: candidate.window.frame.size, scale: scale)
        configuration.width = Int(pixelSize.width)
        configuration.height = Int(pixelSize.height)
        configuration.showsCursor = AppSettings.shared.captureCursor
        configuration.shouldBeOpaque = false
        configuration.ignoreShadowsSingleWindow = false
        applyHighQualitySettings(to: configuration)
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    func captureRegion(snapshot: DisplaySnapshot, selection: CGRect) async throws -> CGImage {
        let capture = regionCaptureConfiguration(snapshot: snapshot, selection: selection)
        return try await SCScreenshotManager.captureImage(
            contentFilter: capture.filter,
            configuration: capture.configuration
        )
    }

    func startRegionCaptureStream(
        snapshot: DisplaySnapshot,
        selection: CGRect,
        onFrame: @escaping RegionCaptureStream.FrameHandler,
        onError: @escaping RegionCaptureStream.ErrorHandler
    ) async throws -> RegionCaptureStream {
        let filter = try await liveRegionFilter(snapshot: snapshot)
        let capture = regionCaptureConfiguration(snapshot: snapshot, selection: selection, filter: filter)
        capture.configuration.minimumFrameInterval = LongCapturePipelinePolicy.minimumFrameInterval
        capture.configuration.queueDepth = LongCapturePipelinePolicy.queueDepth
        capture.configuration.pixelFormat = kCVPixelFormatType_32BGRA
        capture.configuration.colorSpaceName = CGColorSpace.sRGB
        capture.configuration.captureResolution = .best
        capture.configuration.scalesToFit = false
        capture.configuration.preservesAspectRatio = true
        capture.configuration.showsCursor = false
        let stream = RegionCaptureStream(
            filter: capture.filter,
            configuration: capture.configuration,
            frameHandler: onFrame,
            errorHandler: onError
        )
        try await stream.start()
        return stream
    }

    private func regionCaptureConfiguration(
        snapshot: DisplaySnapshot,
        selection: CGRect,
        filter suppliedFilter: SCContentFilter? = nil
    ) -> (filter: SCContentFilter, configuration: SCStreamConfiguration) {
        let filter: SCContentFilter
        if let suppliedFilter {
            filter = suppliedFilter
        } else {
            let excludedApplications = snapshot.ownApplication.map { [$0] } ?? []
            filter = SCContentFilter(
                display: snapshot.display,
                excludingApplications: excludedApplications,
                exceptingWindows: []
            )
        }
        let configuration = SCStreamConfiguration()
        let fixedSelection = selection.integral.intersection(
            CGRect(origin: .zero, size: snapshot.screen.frame.size)
        )
        configuration.sourceRect = CGRect(
            x: fixedSelection.minX,
            y: snapshot.screen.frame.height - fixedSelection.maxY,
            width: fixedSelection.width,
            height: fixedSelection.height
        )
        let scale = nativeScale(for: snapshot.screen, displayID: snapshot.display.displayID)
        let pixelSize = CaptureGeometry.nativePixelSize(logicalSize: fixedSelection.size, scale: scale)
        configuration.width = Int(pixelSize.width)
        configuration.height = Int(pixelSize.height)
        configuration.showsCursor = AppSettings.shared.captureCursor
        configuration.shouldBeOpaque = false
        applyHighQualitySettings(to: configuration)
        return (filter, configuration)
    }

    private func applyHighQualitySettings(to configuration: SCStreamConfiguration) {
        configuration.captureResolution = .best
        configuration.scalesToFit = false
        configuration.preservesAspectRatio = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
    }

    private func liveRegionFilter(snapshot: DisplaySnapshot) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == snapshot.display.displayID }) else {
            throw CaptureServiceError.displayUnavailable
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        if let ownApplication = content.applications.first(where: { $0.bundleIdentifier == ownBundleID }) {
            return SCContentFilter(
                display: display,
                excludingApplications: [ownApplication],
                exceptingWindows: []
            )
        }

        let ownWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == ownBundleID }
        if !ownWindows.isEmpty {
            return SCContentFilter(display: display, excludingWindows: ownWindows)
        }
        if let ownApplication = snapshot.ownApplication {
            return SCContentFilter(
                display: display,
                excludingApplications: [ownApplication],
                exceptingWindows: []
            )
        }
        throw CaptureServiceError.captureFailed
    }

    private func nativeScale(for screen: NSScreen, displayID: CGDirectDisplayID? = nil) -> CGFloat {
        let resolvedDisplayID = displayID
            ?? self.displayID(for: screen)
        if let resolvedDisplayID,
           let mode = CGDisplayCopyDisplayMode(resolvedDisplayID),
           mode.width > 0 {
            return CGFloat(mode.pixelWidth) / CGFloat(mode.width)
        }
        return max(1, screen.backingScaleFactor)
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
        if let number = value as? NSNumber, number.uint32Value != 0 {
            return number.uint32Value
        }
        if let displayID = value as? CGDirectDisplayID, displayID != 0 {
            return displayID
        }
        return nil
    }
}

private extension CGRect {
    var area: CGFloat {
        guard isFinite, !isNull, !isEmpty else { return 0 }
        return width * height
    }

    var isFinite: Bool {
        origin.x.isFinite && origin.y.isFinite && width.isFinite && height.isFinite
    }
}
