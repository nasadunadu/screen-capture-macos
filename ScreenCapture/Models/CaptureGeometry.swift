import AppKit
import CoreGraphics

enum CaptureGeometry {
    static func nativePixelSize(logicalSize: CGSize, scale: CGFloat) -> CGSize {
        let width = logicalSize.width.isFinite && logicalSize.width > 0 ? logicalSize.width : 1
        let height = logicalSize.height.isFinite && logicalSize.height > 0 ? logicalSize.height : 1
        let safeScale = scale.isFinite ? max(scale, 1) : 1
        return CGSize(
            width: max(1, ceil(width * safeScale)),
            height: max(1, ceil(height * safeScale))
        )
    }

    static func crop(
        image: CGImage,
        selection: CGRect,
        canvasSize: CGSize
    ) -> CGImage? {
        guard canvasSize.width.isFinite,
              canvasSize.height.isFinite,
              canvasSize.width > 0,
              canvasSize.height > 0,
              selection.origin.x.isFinite,
              selection.origin.y.isFinite,
              selection.width.isFinite,
              selection.height.isFinite,
              selection.width > 0,
              selection.height > 0 else { return nil }

        let scaleX = CGFloat(image.width) / canvasSize.width
        let scaleY = CGFloat(image.height) / canvasSize.height
        let pixelRect = CGRect(
            x: selection.minX * scaleX,
            y: (canvasSize.height - selection.maxY) * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clamped = pixelRect.intersection(imageBounds)
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return nil }
        return image.cropping(to: clamped)
    }

    static func appKitFrame(
        for screenCaptureFrame: CGRect,
        displayBounds: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        let localX = screenCaptureFrame.minX - displayBounds.minX
        let localY = displayBounds.height - (screenCaptureFrame.maxY - displayBounds.minY)
        return CGRect(
            x: screenFrame.minX + localX,
            y: screenFrame.minY + localY,
            width: screenCaptureFrame.width,
            height: screenCaptureFrame.height
        )
    }

    static func localFrame(globalFrame: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: globalFrame.minX - screen.frame.minX,
            y: globalFrame.minY - screen.frame.minY,
            width: globalFrame.width,
            height: globalFrame.height
        )
    }
}
