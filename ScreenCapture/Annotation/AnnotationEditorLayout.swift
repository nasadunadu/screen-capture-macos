import CoreGraphics

enum AnnotationEditorLayout {
    static func dimmingFrames(screenFrame: CGRect, selectionFrame: CGRect) -> [CGRect] {
        let selection = selectionFrame.intersection(screenFrame)
        guard !selection.isNull, !selection.isEmpty else { return [screenFrame] }

        return [
            CGRect(
                x: screenFrame.minX,
                y: selection.maxY,
                width: screenFrame.width,
                height: max(0, screenFrame.maxY - selection.maxY)
            ),
            CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: max(0, selection.minY - screenFrame.minY)
            ),
            CGRect(
                x: screenFrame.minX,
                y: selection.minY,
                width: max(0, selection.minX - screenFrame.minX),
                height: selection.height
            ),
            CGRect(
                x: selection.maxX,
                y: selection.minY,
                width: max(0, screenFrame.maxX - selection.maxX),
                height: selection.height
            )
        ].filter { $0.width >= 1 && $0.height >= 1 }
    }

    static func toolbarFrame(
        visibleFrame: CGRect,
        selectionFrame: CGRect,
        desiredSize: CGSize,
        gap: CGFloat = 8,
        margin: CGFloat = 12
    ) -> CGRect {
        let availableWidth = max(1, visibleFrame.width - margin * 2)
        let availableHeight = max(1, visibleFrame.height - margin * 2)
        let width = min(desiredSize.width, availableWidth)
        let height = min(desiredSize.height, availableHeight)

        let preferredX = selectionFrame.maxX - width
        let x = min(
            max(preferredX, visibleFrame.minX + margin),
            visibleFrame.maxX - width - margin
        )

        let belowY = selectionFrame.minY - height - gap
        let y: CGFloat
        if belowY >= visibleFrame.minY + margin {
            y = belowY
        } else {
            y = min(
                max(selectionFrame.maxY + gap, visibleFrame.minY + margin),
                visibleFrame.maxY - height - margin
            )
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
