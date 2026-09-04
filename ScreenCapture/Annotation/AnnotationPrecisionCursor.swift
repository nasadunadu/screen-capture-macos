import AppKit

@MainActor
enum AnnotationPrecisionCursor {
    static let imageSize = CGSize(width: 30, height: 30)
    static let hotSpot = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)

    static let cursor: NSCursor = {
        let image = NSImage(size: imageSize, flipped: false) { _ in
            let center = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
            let armGap: CGFloat = 4
            let armEnd: CGFloat = 2
            let path = NSBezierPath()
            path.move(to: CGPoint(x: armEnd, y: center.y))
            path.line(to: CGPoint(x: center.x - armGap, y: center.y))
            path.move(to: CGPoint(x: center.x + armGap, y: center.y))
            path.line(to: CGPoint(x: imageSize.width - armEnd, y: center.y))
            path.move(to: CGPoint(x: center.x, y: armEnd))
            path.line(to: CGPoint(x: center.x, y: center.y - armGap))
            path.move(to: CGPoint(x: center.x, y: center.y + armGap))
            path.line(to: CGPoint(x: center.x, y: imageSize.height - armEnd))
            path.lineCapStyle = .round

            NSColor.white.withAlphaComponent(0.92).setStroke()
            path.lineWidth = 3
            path.stroke()

            CaptureAppearance.selectionColor.setStroke()
            path.lineWidth = 1.4
            path.stroke()

            let centerDot = NSBezierPath(ovalIn: CGRect(
                x: center.x - 2,
                y: center.y - 2,
                width: 4,
                height: 4
            ))
            NSColor.white.setFill()
            centerDot.fill()
            CaptureAppearance.selectionColor.setStroke()
            centerDot.lineWidth = 1.25
            centerDot.stroke()
            return true
        }
        image.isTemplate = false
        return NSCursor(image: image, hotSpot: hotSpot)
    }()

    static func isUsed(for tool: AnnotationTool) -> Bool {
        tool == .line || tool == .arrow
    }
}
