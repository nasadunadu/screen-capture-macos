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
        guard let screen = requestedScreen ?? screenUnderPointer(),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw CaptureServiceError.displayUnavailable
        }

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
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
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
            ?? (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
        if let resolvedDisplayID,
           let mode = CGDisplayCopyDisplayMode(resolvedDisplayID),
           mode.width > 0 {
            return CGFloat(mode.pixelWidth) / CGFloat(mode.width)
        }
        return max(1, screen.backingScaleFactor)
    }
}
