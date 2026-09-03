import AppKit
import SwiftUI

enum SelectionResult {
    case region(RegionSelectionResult)
    case window(WindowCandidate)
}

enum RegionSelectionAction {
    case edit(initialTool: AnnotationTool?)
    case defaultExport
    case saveAs
    case longCapture
}

struct RegionSelectionResult {
    let rect: CGRect
    let image: CGImage
    let style: AnnotationStyle
    let action: RegionSelectionAction
}

@MainActor
final class SelectionOverlayController: NSObject {
    private let snapshot: DisplaySnapshot
    private let mode: CaptureMode
    private var panel: EditorPanel?
    private var toolbarPanel: EditorPanel?
    private weak var selectionView: SelectionOverlayView?
    private let annotationDocument = AnnotationDocument()
    var onResult: ((SelectionResult) -> Void)?
    var onCancel: (() -> Void)?

    init(snapshot: DisplaySnapshot, mode: CaptureMode) {
        self.snapshot = snapshot
        self.mode = mode
        super.init()
    }

    func present() {
        let frame = snapshot.screen.frame
        let panel = EditorPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false

        let view = SelectionOverlayView(
            frame: CGRect(origin: .zero, size: frame.size),
            snapshot: snapshot,
            mode: mode,
            document: annotationDocument
        )
        view.onResult = { [weak self] result in
            self?.finish(with: result)
        }
        view.onSelectionReady = { [weak self] rect in
            self?.presentToolbar(for: rect)
        }
        view.onInteraction = { [weak self] in
            self?.keepToolbarVisible()
        }
        view.onConfirm = { [weak self] in
            guard let self else { return }
            let action: RegionSelectionAction = mode == .longCapture ? .longCapture : .defaultExport
            selectionView?.complete(action: action, style: annotationDocument.style)
        }
        view.onCancel = { [weak self] in
            self?.cancel()
        }
        panel.contentView = view
        self.panel = panel
        selectionView = view
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
    }

    func selectPreset(size: CGSize) {
        let canvas = snapshot.screen.frame.size
        let pointer = NSEvent.mouseLocation
        let local = CGPoint(x: pointer.x - snapshot.screen.frame.minX, y: pointer.y - snapshot.screen.frame.minY)
        var rect = CGRect(
            x: local.x - size.width / 2,
            y: local.y - size.height / 2,
            width: min(size.width, canvas.width),
            height: min(size.height, canvas.height)
        )
        rect.origin.x = min(max(0, rect.origin.x), canvas.width - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), canvas.height - rect.height)
        guard let image = CaptureGeometry.crop(image: snapshot.image, selection: rect, canvasSize: canvas) else {
            cancel()
            return
        }
        finish(with: .region(RegionSelectionResult(
            rect: rect,
            image: image,
            style: annotationDocument.style,
            action: .edit(initialTool: nil)
        )))
    }

    func selectPrevious(rect: CGRect) {
        let bounds = CGRect(origin: .zero, size: snapshot.screen.frame.size)
        let clamped = rect.intersection(bounds)
        guard clamped.width > 4,
              clamped.height > 4,
              let image = CaptureGeometry.crop(
                image: snapshot.image,
                selection: clamped,
                canvasSize: snapshot.screen.frame.size
              ) else {
            cancel()
            return
        }
        finish(with: .region(RegionSelectionResult(
            rect: clamped,
            image: image,
            style: annotationDocument.style,
            action: .edit(initialTool: nil)
        )))
    }

    private func presentToolbar(for localRect: CGRect) {
        guard mode != .window else { return }
        let screen = snapshot.screen
        let globalRect = CGRect(
            x: screen.frame.minX + localRect.minX,
            y: screen.frame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )

        if let toolbarPanel {
            let desiredSize = toolbarPanel.frame.size
            toolbarPanel.setFrame(
                AnnotationEditorLayout.toolbarFrame(
                    visibleFrame: screen.visibleFrame,
                    selectionFrame: globalRect,
                    desiredSize: desiredSize
                ),
                display: true
            )
            keepToolbarVisible()
            return
        }

        let toolbarView = AnnotationToolbarView(
            document: annotationDocument,
            supportsLongCapture: true,
            onLongCapture: { [weak self] in
                self?.selectionView?.complete(
                    action: .longCapture,
                    style: self?.annotationDocument.style ?? AnnotationStyle()
                )
            },
            onSave: { [weak self] in
                guard let self else { return }
                let action: RegionSelectionAction = mode == .longCapture ? .longCapture : .defaultExport
                selectionView?.complete(action: action, style: annotationDocument.style)
            },
            onSaveAs: { [weak self] in
                self?.selectionView?.complete(
                    action: .saveAs,
                    style: self?.annotationDocument.style ?? AnnotationStyle()
                )
            },
            onCancel: { [weak self] in self?.cancel() }
        )
        let hostingView = NSHostingView(rootView: toolbarView)
        let fittingSize = hostingView.fittingSize
        let desiredSize = CGSize(width: ceil(fittingSize.width), height: 62)
        let toolbarFrame = AnnotationEditorLayout.toolbarFrame(
            visibleFrame: screen.visibleFrame,
            selectionFrame: globalRect,
            desiredSize: desiredSize
        )
        let toolbarPanel = EditorPanel(
            contentRect: toolbarFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toolbarPanel.level = .screenSaver
        toolbarPanel.backgroundColor = .clear
        toolbarPanel.isOpaque = false
        toolbarPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toolbarPanel.contentView = hostingView
        toolbarPanel.orderFront(nil)
        self.toolbarPanel = toolbarPanel
        if let panel {
            toolbarPanel.keepAbove(panel)
        }
        panel?.makeKey()
        keepToolbarVisible()
    }

    private func keepToolbarVisible() {
        guard let toolbarPanel else { return }
        if let panel {
            toolbarPanel.keepAbove(panel)
        } else {
            toolbarPanel.orderFrontRegardless()
        }
    }

    private func finish(with result: SelectionResult) {
        toolbarPanel?.orderOut(nil)
        panel?.orderOut(nil)
        toolbarPanel = nil
        panel = nil
        selectionView = nil
        onResult?(result)
    }

    func cancel() {
        toolbarPanel?.orderOut(nil)
        panel?.orderOut(nil)
        toolbarPanel = nil
        panel = nil
        selectionView = nil
        onCancel?()
    }
}

@MainActor
private final class SelectionOverlayView: NSView {
    private enum DragOperation: Equatable {
        case creating
        case moving
        case resizing(SelectionHandle)
    }

    private let snapshot: DisplaySnapshot
    private let mode: CaptureMode
    private let document: AnnotationDocument
    private let backgroundImage: NSImage
    private var selection: CGRect = .zero
    private var dragOrigin: CGPoint?
    private var selectionAtDragStart: CGRect = .zero
    private var dragOperation: DragOperation?
    private var hoveredWindow: WindowCandidate?
    private weak var annotationCanvas: AnnotationCanvasView?
    var onResult: ((SelectionResult) -> Void)?
    var onSelectionReady: ((CGRect) -> Void)?
    var onInteraction: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    init(frame: CGRect, snapshot: DisplaySnapshot, mode: CaptureMode, document: AnnotationDocument) {
        self.snapshot = snapshot
        self.mode = mode
        self.document = document
        backgroundImage = NSImage(cgImage: snapshot.image, size: frame.size)
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard mode != .window,
              selection.width >= 6,
              selection.height >= 6 else { return super.hitTest(point) }
        if shadowControlFrame(for: selection).contains(point) {
            return self
        }
        if document.elements.isEmpty,
           SelectionGeometry.handle(at: point, in: selection) != nil {
            return self
        }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        if let rect = SelectionGeometry.cursorRect(bounds, inside: bounds) {
            addCursorRect(rect, cursor: .crosshair)
        }
        guard mode != .window, selection.width >= 6, selection.height >= 6 else { return }
        if annotationCanvas == nil,
           let interior = SelectionGeometry.cursorRect(selection.insetBy(dx: 8, dy: 8), inside: bounds) {
            addCursorRect(interior, cursor: .openHand)
        }
        for handle in SelectionHandle.allCases {
            let point = handle.point(in: selection)
            let cursor: NSCursor
            switch handle {
            case .left, .right:
                cursor = .resizeLeftRight
            case .top, .bottom:
                cursor = .resizeUpDown
            default:
                cursor = .crosshair
            }
            let hitRect = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
            if let clipped = SelectionGeometry.cursorRect(hitRect, inside: bounds) {
                addCursorRect(clipped, cursor: cursor)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        NSColor.black.withAlphaComponent(0.48).setFill()
        bounds.fill()

        let visibleSelection = mode == .window ? hoveredWindow?.localFrame ?? .zero : selection
        guard visibleSelection.width > 0, visibleSelection.height > 0 else {
            drawHint()
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: visibleSelection).addClip()
        backgroundImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(rect: visibleSelection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 2
        CaptureAppearance.selectionColor.setStroke()
        border.stroke()
        drawCornerBrackets(for: visibleSelection)
        if mode != .window { drawSelectionHeader(for: visibleSelection) }
    }

    override func mouseMoved(with event: NSEvent) {
        guard mode == .window else { return }
        let point = convert(event.locationInWindow, from: nil)
        hoveredWindow = snapshot.windows.first(where: { $0.localFrame.contains(point) })
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if mode == .window {
            if let hoveredWindow { onResult?(.window(hoveredWindow)) }
            return
        }

        if selection.width >= 6,
           selection.height >= 6,
           shadowControlFrame(for: selection).contains(point) {
            AppSettings.shared.shadowEnabled.toggle()
            needsDisplay = true
            return
        }

        // Once annotation begins the selected crop is fixed. Interior events
        // belong to the canvas; stray clicks outside it must not discard work.
        if annotationCanvas != nil, !document.elements.isEmpty { return }

        dragOrigin = point
        selectionAtDragStart = selection
        if document.elements.isEmpty,
           selection.width >= 6,
           selection.height >= 6,
           let handle = SelectionGeometry.handle(at: point, in: selection) {
            dragOperation = .resizing(handle)
            annotationCanvas?.isHidden = true
        } else if annotationCanvas == nil,
                  selection.contains(point), selection.width >= 6, selection.height >= 6 {
            dragOperation = .moving
        } else {
            dragOperation = .creating
            annotationCanvas?.isHidden = true
            selection = CGRect(origin: point, size: .zero)
            selectionAtDragStart = selection
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let dragOperation, mode != .window else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch dragOperation {
        case .creating:
            selection = CGRect(
                x: min(dragOrigin.x, point.x),
                y: min(dragOrigin.y, point.y),
                width: abs(point.x - dragOrigin.x),
                height: abs(point.y - dragOrigin.y)
            ).intersection(bounds)
        case .moving:
            selection = SelectionGeometry.moved(
                rect: selectionAtDragStart,
                by: CGSize(width: point.x - dragOrigin.x, height: point.y - dragOrigin.y),
                inside: bounds
            )
        case let .resizing(handle):
            selection = SelectionGeometry.resized(
                rect: selectionAtDragStart,
                handle: handle,
                to: point,
                inside: bounds
            )
        }
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard mode != .window else { return }
        selection = selection.integral.intersection(bounds)
        if selection.width < 6 || selection.height < 6 { selection = .zero }
        dragOrigin = nil
        dragOperation = nil
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
        if selection.width >= 6, selection.height >= 6 {
            installAnnotationCanvas()
            onSelectionReady?(selection)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            onConfirm?()
            return
        }
        super.keyDown(with: event)
    }

    func complete(action: RegionSelectionAction, style: AnnotationStyle) {
        let fixedSelection = selection.integral.intersection(bounds)
        guard fixedSelection.width >= 6,
              fixedSelection.height >= 6,
              let sourceImage = CaptureGeometry.crop(
                image: snapshot.image,
                selection: fixedSelection,
                canvasSize: bounds.size
              ) else { return }
        let image: CGImage
        switch action {
        case .longCapture:
            image = sourceImage
        case .edit, .defaultExport, .saveAs:
            image = annotationCanvas?.renderedImage() ?? sourceImage
        }
        onResult?(.region(RegionSelectionResult(
            rect: fixedSelection,
            image: image,
            style: style,
            action: action
        )))
    }

    private func installAnnotationCanvas() {
        guard document.elements.isEmpty else {
            annotationCanvas?.isHidden = false
            return
        }
        let fixedSelection = selection.integral.intersection(bounds)
        guard fixedSelection.width >= 6,
              fixedSelection.height >= 6,
              let image = CaptureGeometry.crop(
                image: snapshot.image,
                selection: fixedSelection,
                canvasSize: bounds.size
              ) else { return }

        annotationCanvas?.removeFromSuperview()
        let canvasFrame = fixedSelection.insetBy(dx: 2, dy: 2)
        guard canvasFrame.width >= 2, canvasFrame.height >= 2 else { return }
        let canvas = AnnotationCanvasView(image: image, frame: canvasFrame, document: document)
        canvas.onConfirm = { [weak self] in self?.onConfirm?() }
        canvas.onCancel = { [weak self] in self?.onCancel?() }
        canvas.onInteraction = { [weak self] in self?.onInteraction?() }
        addSubview(canvas)
        annotationCanvas = canvas
        window?.makeFirstResponder(canvas)
    }

    private func drawHint() {
        let text = mode == .window ? "移动光标并点击窗口 · Esc 取消" : "拖动选择截图区域 · 松开后可调整 · Esc 取消"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(x: bounds.midX - size.width / 2 - 14, y: bounds.midY - 19, width: size.width + 28, height: 38)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
        text.draw(at: CGPoint(x: rect.minX + 14, y: rect.midY - size.height / 2), withAttributes: attributes)
    }

    private func drawCornerBrackets(for rect: CGRect) {
        let length: CGFloat = 19
        let lineWidth: CGFloat = 6
        // The selection border is 2 pt wide. Moving the bracket centerline
        // 5.5 pt outward leaves a 2 pt visual gap between both strokes.
        let outset: CGFloat = 5.5
        let left = rect.minX - outset
        let right = rect.maxX + outset
        let bottom = rect.minY - outset
        let top = rect.maxY + outset
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .square
        path.lineJoinStyle = .miter
        path.move(to: CGPoint(x: left + length, y: top))
        path.line(to: CGPoint(x: left, y: top))
        path.line(to: CGPoint(x: left, y: top - length))
        path.move(to: CGPoint(x: right - length, y: top))
        path.line(to: CGPoint(x: right, y: top))
        path.line(to: CGPoint(x: right, y: top - length))
        path.move(to: CGPoint(x: left, y: bottom + length))
        path.line(to: CGPoint(x: left, y: bottom))
        path.line(to: CGPoint(x: left + length, y: bottom))
        path.move(to: CGPoint(x: right - length, y: bottom))
        path.line(to: CGPoint(x: right, y: bottom))
        path.line(to: CGPoint(x: right, y: bottom + length))
        CaptureAppearance.selectionColor.setStroke()
        path.stroke()
    }

    private func selectionHeaderFrame(for rect: CGRect) -> CGRect {
        let width = min(238, max(184, rect.width))
        let height: CGFloat = 34
        let x = min(max(rect.minX, bounds.minX + 2), bounds.maxX - width - 2)
        let aboveY = rect.maxY + 5
        let y = aboveY + height <= bounds.maxY - 2 ? aboveY : max(bounds.minY + 2, rect.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func shadowControlFrame(for rect: CGRect) -> CGRect {
        let header = selectionHeaderFrame(for: rect)
        return CGRect(x: header.maxX - 88, y: header.minY, width: 88, height: header.height)
    }

    private func drawSelectionHeader(for rect: CGRect) {
        let header = selectionHeaderFrame(for: rect)
        CaptureAppearance.selectionColor.setFill()
        NSBezierPath(roundedRect: header, xRadius: 6, yRadius: 6).fill()

        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: header.minX + 11, y: header.midY - size.height / 2),
            withAttributes: attributes
        )

        let shadowFrame = shadowControlFrame(for: rect)
        NSColor.black.withAlphaComponent(0.10).setFill()
        NSBezierPath(roundedRect: shadowFrame, xRadius: 6, yRadius: 6).fill()
        let shadowText = AppSettings.shared.shadowEnabled ? "✓  阴影" : "○  阴影"
        let shadowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let shadowSize = shadowText.size(withAttributes: shadowAttributes)
        shadowText.draw(
            at: CGPoint(x: shadowFrame.midX - shadowSize.width / 2, y: shadowFrame.midY - shadowSize.height / 2),
            withAttributes: shadowAttributes
        )
    }
}
