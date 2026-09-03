import CoreGraphics

enum SelectionHandle: CaseIterable, Equatable {
    case bottomLeft
    case bottom
    case bottomRight
    case left
    case right
    case topLeft
    case top
    case topRight

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .bottom: CGPoint(x: rect.midX, y: rect.minY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .topLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .top: CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

enum SelectionGeometry {
    static func cursorRect(_ rect: CGRect, inside bounds: CGRect) -> CGRect? {
        guard rect.size.width > 0,
              rect.size.height > 0,
              rect.minX.isFinite,
              rect.minY.isFinite,
              rect.size.width.isFinite,
              rect.size.height.isFinite else { return nil }
        let clipped = rect.intersection(bounds)
        guard !clipped.isNull,
              clipped.width >= 1,
              clipped.height >= 1 else { return nil }
        return clipped
    }

    static func handle(at point: CGPoint, in rect: CGRect, tolerance: CGFloat = 10) -> SelectionHandle? {
        SelectionHandle.allCases.first { handle in
            let location = handle.point(in: rect)
            return abs(location.x - point.x) <= tolerance && abs(location.y - point.y) <= tolerance
        }
    }

    static func moved(rect: CGRect, by delta: CGSize, inside bounds: CGRect) -> CGRect {
        guard rect.width <= bounds.width, rect.height <= bounds.height else {
            return rect.intersection(bounds)
        }
        return CGRect(
            x: min(max(rect.minX + delta.width, bounds.minX), bounds.maxX - rect.width),
            y: min(max(rect.minY + delta.height, bounds.minY), bounds.maxY - rect.height),
            width: rect.width,
            height: rect.height
        )
    }

    static func resized(
        rect: CGRect,
        handle: SelectionHandle,
        to point: CGPoint,
        inside bounds: CGRect,
        minimumSize: CGFloat = 6
    ) -> CGRect {
        let point = CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .bottomLeft, .left, .topLeft:
            minX = min(point.x, maxX - minimumSize)
        case .bottomRight, .right, .topRight:
            maxX = max(point.x, minX + minimumSize)
        case .bottom, .top:
            break
        }

        switch handle {
        case .bottomLeft, .bottom, .bottomRight:
            minY = min(point.y, maxY - minimumSize)
        case .topLeft, .top, .topRight:
            maxY = max(point.y, minY + minimumSize)
        case .left, .right:
            break
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .intersection(bounds)
    }
}
