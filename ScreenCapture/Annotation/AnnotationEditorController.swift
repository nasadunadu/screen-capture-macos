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

    func keepAbove(_ parent: NSWindow) {
        if parent.childWindows?.contains(where: { $0 === self }) != true {
            parent.addChildWindow(self, ordered: .above)
        }
        orderFrontRegardless()
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

@MainActor
final class AnnotationEditorController: NSObject {
    private let image: CGImage
    private let document: AnnotationDocument
    private let context: CaptureContext?
    private var dimmingPanels: [NSPanel] = []
    private var canvasPanel: EditorPanel?
    private var toolbarPanel: EditorPanel?
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
        toolbarPanel?.orderOut(nil)
        dimmingPanels.removeAll()
        canvasPanel = nil
        toolbarPanel = nil
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

        let panel = EditorPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let canvas = AnnotationCanvasView(
            image: image,
            frame: CGRect(origin: .zero, size: frame.size),
            document: document
        )
        canvas.onConfirm = { [weak self] in self?.finish() }
        canvas.onCancel = { [weak self] in self?.close() }
        canvas.onInteraction = { [weak self] in
            self?.toolbarPanel?.orderFrontRegardless()
        }
        panel.contentView = canvas
        panel.makeKeyAndOrderFront(nil)
        self.canvasPanel = panel
        self.canvas = canvas

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
        toolbarPanel.contentView = toolbarHostingView
        toolbarPanel.orderFront(nil)
        self.toolbarPanel = toolbarPanel
        toolbarPanel.keepAbove(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        toolbarPanel.orderFrontRegardless()
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
