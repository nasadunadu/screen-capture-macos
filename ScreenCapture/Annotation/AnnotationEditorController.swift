import AppKit
import SwiftUI

struct CaptureContext {
    let snapshot: DisplaySnapshot
    let selectionRect: CGRect
    let globalFrame: CGRect
}

final class EditorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backingStoreType,
            defer: flag
        )
        hidesOnDeactivate = false
    }

}

private final class AnnotationDimmingView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.48).setFill()
        dirtyRect.fill()
    }
}

/// Single-window host for the annotation canvas and toolbar.
///
/// The previous editor used a second NSPanel for the toolbar. Making the
/// toolbar a strong subview of this root view gives AppKit one responder and
/// one z-order tree for all annotation interactions.
@MainActor
final class AnnotationEditorRootView: NSView {
    private var toolbar: NSView?

    func addCanvas(_ canvas: NSView) {
        canvas.removeFromSuperview()
        addSubview(canvas, positioned: .below, relativeTo: toolbar)
    }

    func installToolbar(_ toolbar: NSView, frame: CGRect) {
        toolbar.removeFromSuperview()
        toolbar.frame = frame.integral
        toolbar.autoresizingMask = []
        addSubview(toolbar, positioned: .above, relativeTo: nil)
        self.toolbar = toolbar
        toolbar.isHidden = false
    }

    func keepToolbarVisible() {
        guard let toolbar else { return }
        toolbar.isHidden = false
    }
}

@MainActor
final class AnnotationEditorController: NSObject {
    private let image: CGImage
    private let document: AnnotationDocument
    private let context: CaptureContext?
    private var dimmingPanels: [NSPanel] = []
    private var canvasPanel: EditorPanel?
    private var canvas: AnnotationCanvasView?
    private var exportTask: Task<Void, Never>?
    var onClose: (() -> Void)?
    var onLongCapture: ((CaptureContext) -> Void)?

    init(
        image: CGImage,
        globalFrame: CGRect,
        context: CaptureContext?,
        initialTool: AnnotationTool? = nil,
        initialStyle: AnnotationStyle? = nil
    ) {
        self.image = image
        self.context = context
        let document = AnnotationDocument()
        if let initialTool { document.tool = initialTool }
        if let initialStyle { document.style = initialStyle }
        self.document = document
        super.init()
        present(globalFrame: globalFrame)
    }

    func close() {
        exportTask?.cancel()
        exportTask = nil
        dimmingPanels.forEach { $0.orderOut(nil) }
        canvasPanel?.orderOut(nil)
        dimmingPanels.removeAll()
        canvasPanel = nil
        onClose?()
    }

    private func present(globalFrame requestedFrame: CGRect) {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(requestedFrame) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? requestedFrame
        var frame = requestedFrame
        if frame.width > visible.width { frame.size.width = visible.width }
        if frame.height > visible.height - 70 { frame.size.height = visible.height - 70 }
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY + 60), visible.maxY - frame.height)

        if let screen {
            presentDimmingPanels(screenFrame: screen.frame, selectionFrame: frame)
        }

        let toolbarView = AnnotationToolbarView(
            document: document,
            supportsLongCapture: context != nil,
            onLongCapture: { [weak self] in self?.beginLongCapture() },
            onSave: { [weak self] in self?.finish() },
            onSaveAs: { [weak self] in self?.saveAs() },
            onCancel: { [weak self] in self?.close() }
        )
        let toolbarHostingView = NSHostingView(rootView: toolbarView)
        let fittingSize = toolbarHostingView.fittingSize
        let toolbarFrame = AnnotationEditorLayout.toolbarFrame(
            visibleFrame: visible,
            selectionFrame: frame,
            desiredSize: CGSize(width: ceil(fittingSize.width), height: 62)
        )
        let rootFrame = frame.union(toolbarFrame)
        let panel = EditorPanel(
            contentRect: rootFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let rootView = AnnotationEditorRootView(frame: CGRect(origin: .zero, size: rootFrame.size))
        let canvas = AnnotationCanvasView(
            image: image,
            frame: CGRect(
                x: frame.minX - rootFrame.minX,
                y: frame.minY - rootFrame.minY,
                width: frame.width,
                height: frame.height
            ),
            document: document
        )
        canvas.onConfirm = { [weak self] in self?.finish() }
        canvas.onCancel = { [weak self] in self?.close() }
        canvas.onInteraction = { [weak self] in
            self?.keepToolbarVisible()
        }
        rootView.addCanvas(canvas)
        rootView.installToolbar(
            toolbarHostingView,
            frame: toolbarFrame.offsetBy(dx: -rootFrame.minX, dy: -rootFrame.minY)
        )
        panel.contentView = rootView
        panel.makeKeyAndOrderFront(nil)
        self.canvasPanel = panel
        self.canvas = canvas
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        rootView.keepToolbarVisible()
    }

    private func keepToolbarVisible() {
        guard let rootView = canvasPanel?.contentView as? AnnotationEditorRootView else { return }
        rootView.keepToolbarVisible()
    }

    private func presentDimmingPanels(screenFrame: CGRect, selectionFrame: CGRect) {
        dimmingPanels = AnnotationEditorLayout.dimmingFrames(
            screenFrame: screenFrame,
            selectionFrame: selectionFrame
        ).map { frame in
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = AnnotationDimmingView(frame: CGRect(origin: .zero, size: frame.size))
            panel.orderFront(nil)
            return panel
        }
    }

    private func renderedImage() -> CGImage? { canvas?.renderedImage() }

    private func finish() {
        guard exportTask == nil, let image = renderedImage() else { return }
        exportTask = Task { @MainActor [weak self] in
            do {
                _ = try await ImageExporter.shared.performDefaultAction(image: image)
                guard !Task.isCancelled else { return }
                self?.exportTask = nil
                self?.close()
            } catch is CancellationError {
                self?.exportTask = nil
            } catch {
                self?.exportTask = nil
                self?.show(error)
            }
        }
    }

    private func saveAs() {
        guard exportTask == nil, let image = renderedImage() else { return }
        exportTask = Task { @MainActor [weak self] in
            do {
                let url = try await ImageExporter.shared.saveAs(image: image)
                guard !Task.isCancelled else { return }
                self?.exportTask = nil
                if url != nil { self?.close() }
            } catch is CancellationError {
                self?.exportTask = nil
            } catch {
                self?.exportTask = nil
                self?.show(error)
            }
        }
    }

    private func beginLongCapture() {
        guard let context else { return }
        close()
        onLongCapture?(context)
    }

    private func show(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
