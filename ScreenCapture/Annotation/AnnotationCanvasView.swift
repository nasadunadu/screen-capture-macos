import AppKit
import Combine

@MainActor
final class AnnotationCanvasView: NSView, NSTextFieldDelegate {
    static let keyboardTools: [AnnotationTool] = [
        .rectangle, .ellipse, .line, .arrow, .pen, .text, .spotlight
    ]

    let sourceImage: CGImage
    let document: AnnotationDocument
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    private var activeElementID: UUID?
    private var dragStart: CGPoint?
    private var lastDragPoint: CGPoint?
    private var editingField: NSTextField?
    private var editingElementID: UUID?
    private var cancellable: AnyCancellable?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(image: CGImage, frame: CGRect, document: AnnotationDocument) {
        sourceImage = image
        self.document = document
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        cancellable = document.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawContent(in: bounds, showSelection: true)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2,
           let hit = hitTestElement(at: point),
           hit.tool == .text {
            startTextEditing(element: hit, at: hit.start)
            return
        }

        if document.tool == .select {
            let hit = hitTestElement(at: point)
            document.selectedElementID = hit?.id
            activeElementID = hit?.id
            dragStart = point
            lastDragPoint = point
            if hit != nil { document.beginMutation() }
            needsDisplay = true
            return
        }

        if document.tool == .text {
            startTextEditing(element: nil, at: point)
            return
        }

        document.beginMutation()
        let points = document.tool == .pen ? [point] : []
        let element = AnnotationElement(
            tool: document.tool,
            start: point,
            end: point,
            points: points,
            style: document.style
        )
        activeElementID = element.id
        document.append(element)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let activeElementID,
              var element = document.element(id: activeElementID) else { return }

        if document.tool == .select {
            guard let lastDragPoint else { return }
            element.translate(by: CGSize(width: point.x - lastDragPoint.x, height: point.y - lastDragPoint.y))
            self.lastDragPoint = point
        } else if element.tool == .pen {
            element.points.append(point)
            element.end = point
        } else {
            element.end = point
        }
        document.update(element)
    }

    override func mouseUp(with event: NSEvent) {
        activeElementID = nil
        dragStart = nil
        lastDragPoint = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
            event.modifierFlags.contains(.shift) ? document.redo() : document.undo()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            document.removeSelected()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            onConfirm?()
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        if let value = Int(event.charactersIgnoringModifiers ?? ""),
           Self.keyboardTools.indices.contains(value - 1) {
            document.tool = Self.keyboardTools[value - 1]
            return
        }
        super.keyDown(with: event)
    }

    func renderedImage() -> CGImage? {
        finishTextEditing()
        let width = sourceImage.width
        let height = sourceImage.height
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(
            x: CGFloat(width) / max(bounds.width, 1),
            y: CGFloat(height) / max(bounds.height, 1)
        )
        drawContent(in: bounds, showSelection: false)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    private func drawContent(in rect: CGRect, showSelection: Bool) {
        let source = NSImage(cgImage: sourceImage, size: rect.size)
        source.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        for element in document.elements { draw(element: element, in: rect) }
        if showSelection,
           let id = document.selectedElementID,
           let element = document.element(id: id) {
            let path = NSBezierPath(rect: element.bounds.insetBy(dx: -5, dy: -5))
            path.setLineDash([5, 4], count: 2, phase: 0)
            path.lineWidth = 1
            NSColor.controlAccentColor.setStroke()
            path.stroke()
        }
    }

    private func draw(element: AnnotationElement, in canvas: CGRect) {
        let color = element.style.color.withAlphaComponent(element.style.opacity)
        color.setStroke()
        color.setFill()

        switch element.tool {
        case .rectangle:
            drawShape(NSBezierPath(roundedRect: element.bounds, xRadius: 3, yRadius: 3), element: element)
        case .ellipse:
            drawShape(NSBezierPath(ovalIn: element.bounds), element: element)
        case .line:
            let path = NSBezierPath()
            path.move(to: element.start)
            path.line(to: element.end)
            path.lineWidth = element.style.lineWidth
            path.lineCapStyle = .round
            path.stroke()
        case .arrow:
            drawArrow(element)
        case .pen:
            drawFreehand(element)
        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(16, element.style.lineWidth * 4), weight: .semibold),
                .foregroundColor: color
            ]
            element.text.draw(at: element.start, withAttributes: attributes)
        case .spotlight:
            let overlay = NSBezierPath(rect: canvas)
            let hole = element.style.spotlightEllipse ? NSBezierPath(ovalIn: element.bounds) : NSBezierPath(rect: element.bounds)
            overlay.append(hole)
            overlay.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(min(0.8, max(0.15, element.style.opacity * 0.65))).setFill()
            overlay.fill()
        case .select:
            break
        }
    }

    private func drawShape(_ path: NSBezierPath, element: AnnotationElement) {
        path.lineWidth = element.style.lineWidth
        if element.style.filled { path.fill() } else { path.stroke() }
    }

    private func drawArrow(_ element: AnnotationElement) {
        guard let geometry = AnnotationArrowGeometry.make(
            start: element.start,
            end: element.end,
            lineWidth: element.style.lineWidth
        ), let first = geometry.points.first else { return }

        let path = NSBezierPath()
        path.move(to: first)
        for point in geometry.points.dropFirst() { path.line(to: point) }
        path.close()
        path.fill()
    }

    private func drawFreehand(_ element: AnnotationElement) {
        guard let first = element.points.first else { return }
        let path = NSBezierPath()
        path.move(to: first)
        for point in element.points.dropFirst() { path.line(to: point) }
        path.lineWidth = element.style.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func hitTestElement(at point: CGPoint) -> AnnotationElement? {
        document.elements.reversed().first(where: { $0.bounds.insetBy(dx: -10, dy: -10).contains(point) })
    }

    private func startTextEditing(element: AnnotationElement?, at point: CGPoint) {
        editingField?.removeFromSuperview()
        editingElementID = element?.id
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 220, height: 32))
        field.stringValue = element?.text ?? ""
        field.placeholderString = "输入文字"
        field.isBordered = true
        field.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        let editingStyle = element?.style ?? document.style
        field.textColor = editingStyle.color
        field.font = NSFont.systemFont(ofSize: max(16, editingStyle.lineWidth * 4), weight: .semibold)
        field.delegate = self
        addSubview(field)
        editingField = field
        window?.makeFirstResponder(field)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        finishTextEditing()
    }

    private func finishTextEditing() {
        guard let field = editingField else { return }
        editingField = nil
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            document.beginMutation()
            if let editingElementID, var element = document.element(id: editingElementID) {
                element.text = value
                document.update(element)
                document.selectedElementID = element.id
            } else {
                let element = AnnotationElement(
                    tool: .text,
                    start: field.frame.origin,
                    end: field.frame.origin,
                    text: value,
                    style: document.style
                )
                document.append(element)
            }
        }
        field.removeFromSuperview()
        editingElementID = nil
        window?.makeFirstResponder(self)
    }
}
