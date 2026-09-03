import AppKit

enum LongCaptureMaskEdge: Equatable {
    case top
    case bottom
    case left
    case right
}

struct LongCaptureMaskDescriptor {
    let frame: CGRect
    let innerEdge: LongCaptureMaskEdge
}

enum LongCaptureLayout {
    static func maskDescriptors(screenFrame: CGRect, selectionFrame: CGRect) -> [LongCaptureMaskDescriptor] {
        let selection = selectionFrame.intersection(screenFrame)
        return [
            LongCaptureMaskDescriptor(
                frame: CGRect(
                    x: screenFrame.minX,
                    y: selection.maxY,
                    width: screenFrame.width,
                    height: max(0, screenFrame.maxY - selection.maxY)
                ),
                innerEdge: .top
            ),
            LongCaptureMaskDescriptor(
                frame: CGRect(
                    x: screenFrame.minX,
                    y: screenFrame.minY,
                    width: screenFrame.width,
                    height: max(0, selection.minY - screenFrame.minY)
                ),
                innerEdge: .bottom
            ),
            LongCaptureMaskDescriptor(
                frame: CGRect(
                    x: screenFrame.minX,
                    y: selection.minY,
                    width: max(0, selection.minX - screenFrame.minX),
                    height: selection.height
                ),
                innerEdge: .left
            ),
            LongCaptureMaskDescriptor(
                frame: CGRect(
                    x: selection.maxX,
                    y: selection.minY,
                    width: max(0, screenFrame.maxX - selection.maxX),
                    height: selection.height
                ),
                innerEdge: .right
            )
        ].filter { $0.frame.width >= 1 && $0.frame.height >= 1 }
    }

    static func previewFrame(visibleFrame: CGRect, selectionFrame: CGRect) -> CGRect? {
        let gap: CGFloat = 12
        let desiredWidth = min(selectionFrame.width, visibleFrame.width * 0.48)
        let minimumUsefulWidth = min(240, desiredWidth)
        let rightSpace = visibleFrame.maxX - selectionFrame.maxX - gap
        let leftSpace = selectionFrame.minX - visibleFrame.minX - gap

        let width: CGFloat
        let x: CGFloat
        if rightSpace >= minimumUsefulWidth {
            width = min(desiredWidth, rightSpace)
            x = selectionFrame.maxX + gap
        } else if leftSpace >= minimumUsefulWidth {
            width = min(desiredWidth, leftSpace)
            x = selectionFrame.minX - width - gap
        } else {
            return nil
        }

        let height = min(selectionFrame.height, visibleFrame.height - 16)
        let y = min(
            max(selectionFrame.maxY - height, visibleFrame.minY + 8),
            visibleFrame.maxY - height - 8
        )
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

final class LongCaptureMaskView: NSView {
    private let innerEdge: LongCaptureMaskEdge
    private let sizeText: String?

    init(frame: CGRect, innerEdge: LongCaptureMaskEdge, sizeText: String? = nil) {
        self.innerEdge = innerEdge
        self.sizeText = sizeText
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.48).setFill()
        bounds.fill()

        CaptureAppearance.selectionColor.setFill()
        edgeRect.fill()
        drawSizeBadgeIfPossible()
    }

    private var edgeRect: CGRect {
        let thickness: CGFloat = 3
        switch innerEdge {
        case .top:
            return CGRect(x: 0, y: 0, width: bounds.width, height: thickness)
        case .bottom:
            return CGRect(x: 0, y: bounds.maxY - thickness, width: bounds.width, height: thickness)
        case .left:
            return CGRect(x: bounds.maxX - thickness, y: 0, width: thickness, height: bounds.height)
        case .right:
            return CGRect(x: 0, y: 0, width: thickness, height: bounds.height)
        }
    }

    private func drawSizeBadgeIfPossible() {
        guard let sizeText,
              bounds.width >= 230,
              bounds.height >= 34 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let text = "  \(sizeText)  ·  滚动页面开始采集  "
        let textSize = text.size(withAttributes: attributes)
        let badgeSize = CGSize(width: min(textSize.width + 10, bounds.width - 16), height: 28)
        let y: CGFloat = innerEdge == .top ? 7 : bounds.maxY - badgeSize.height - 7
        let badgeRect = CGRect(x: 8, y: y, width: badgeSize.width, height: badgeSize.height)
        CaptureAppearance.selectionColor.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7).fill()
        text.draw(
            at: CGPoint(x: badgeRect.minX + 5, y: badgeRect.midY - textSize.height / 2),
            withAttributes: attributes
        )
    }
}
