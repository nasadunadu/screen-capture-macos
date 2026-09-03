import AppKit
import Carbon.HIToolbox

@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private let service = ScreenCaptureService()
    private var selectionController: SelectionOverlayController?
    private var editorController: AnnotationEditorController?
    private var longCaptureSession: LongCaptureSession?
    private var captureTask: Task<Void, Never>?
    private var workflowGate = CaptureWorkflowGate()
    private let previousRectKey = "previousSelectionRect"
    private let escapeHotKeyID: UInt32 = 9_000

    private init() {}

    func begin(_ mode: CaptureMode) {
        guard let workflowToken = acquireWorkflow() else {
            NSSound.beep()
            return
        }
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if mode == .delayedFullScreen {
                    let seconds = AppSettings.validDelaySeconds(AppSettings.shared.delaySeconds)
                    let nanoseconds = UInt64(seconds * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                }
                let snapshot = try await service.captureDisplay(includeWindows: mode == .window)
                guard !Task.isCancelled, workflowGate.isActive(workflowToken) else {
                    finishWorkflow(workflowToken)
                    return
                }
                captureTask = nil
                switch mode {
                case .fullScreen, .delayedFullScreen:
                    presentEditor(
                        image: snapshot.image,
                        globalFrame: snapshot.screen.frame,
                        context: nil,
                        workflowToken: workflowToken
                    )
                case .presetArea:
                    presentSelection(snapshot: snapshot, mode: .region, workflowToken: workflowToken) { controller in
                        controller.selectPreset(size: CGSize(
                            width: AppSettings.shared.presetWidth,
                            height: AppSettings.shared.presetHeight
                        ))
                    }
                case .previousArea:
                    guard let stored = UserDefaults.standard.string(forKey: previousRectKey) else {
                        presentSelection(snapshot: snapshot, mode: .region, workflowToken: workflowToken)
                        return
                    }
                    presentSelection(snapshot: snapshot, mode: .region, workflowToken: workflowToken) { controller in
                        controller.selectPrevious(rect: NSRectFromString(stored))
                    }
                case .window:
                    presentSelection(snapshot: snapshot, mode: .window, workflowToken: workflowToken)
                case .longCapture:
                    presentSelection(snapshot: snapshot, mode: .longCapture, workflowToken: workflowToken)
                case .region:
                    presentSelection(snapshot: snapshot, mode: .region, workflowToken: workflowToken)
                }
            } catch is CancellationError {
                finishWorkflow(workflowToken)
            } catch {
                if finishWorkflow(workflowToken) { show(error) }
            }
        }
    }

    private func presentSelection(
        snapshot: DisplaySnapshot,
        mode: CaptureMode,
        workflowToken: CaptureWorkflowToken,
        afterPresent: ((SelectionOverlayController) -> Void)? = nil
    ) {
        let controller = SelectionOverlayController(snapshot: snapshot, mode: mode)
        controller.onResult = { [weak self] result in
            self?.selectionController = nil
            self?.handle(
                result: result,
                snapshot: snapshot,
                workflowToken: workflowToken
            )
        }
        controller.onCancel = { [weak self] in
            self?.selectionController = nil
            self?.finishWorkflow(workflowToken)
        }
        selectionController = controller
        if afterPresent == nil { controller.present() }
        afterPresent?(controller)
    }

    private func handle(
        result: SelectionResult,
        snapshot: DisplaySnapshot,
        workflowToken: CaptureWorkflowToken
    ) {
        guard workflowGate.isActive(workflowToken) else { return }
        switch result {
        case let .region(selection):
            let rect = selection.rect
            UserDefaults.standard.set(NSStringFromRect(rect), forKey: previousRectKey)
            let globalFrame = CGRect(
                x: snapshot.screen.frame.minX + rect.minX,
                y: snapshot.screen.frame.minY + rect.minY,
                width: rect.width,
                height: rect.height
            )
            let context = CaptureContext(snapshot: snapshot, selectionRect: rect, globalFrame: globalFrame)
            switch selection.action {
            case let .edit(initialTool):
                presentEditor(
                    image: selection.image,
                    globalFrame: globalFrame,
                    context: context,
                    workflowToken: workflowToken,
                    initialTool: initialTool,
                    initialStyle: selection.style
                )
            case .defaultExport:
                export(
                    image: selection.image,
                    saveAs: false,
                    workflowToken: workflowToken
                )
            case .saveAs:
                export(
                    image: selection.image,
                    saveAs: true,
                    workflowToken: workflowToken
                )
            case .longCapture:
                startLongCapture(context, workflowToken: workflowToken)
            }
        case let .window(candidate):
            captureTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let image = try await service.captureWindow(candidate)
                    guard !Task.isCancelled, workflowGate.isActive(workflowToken) else {
                        finishWorkflow(workflowToken)
                        return
                    }
                    captureTask = nil
                    presentEditor(
                        image: image,
                        globalFrame: candidate.globalFrame,
                        context: nil,
                        workflowToken: workflowToken
                    )
                } catch is CancellationError {
                    finishWorkflow(workflowToken)
                } catch {
                    if finishWorkflow(workflowToken) { show(error) }
                }
            }
        }
    }

    private func export(
        image: CGImage,
        saveAs: Bool,
        workflowToken: CaptureWorkflowToken
    ) {
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if saveAs {
                    _ = try await ImageExporter.shared.saveAs(image: image)
                } else {
                    _ = try await ImageExporter.shared.performDefaultAction(image: image)
                }
                guard !Task.isCancelled else {
                    finishWorkflow(workflowToken)
                    return
                }
                captureTask = nil
                finishWorkflow(workflowToken)
            } catch is CancellationError {
                finishWorkflow(workflowToken)
            } catch {
                if finishWorkflow(workflowToken) { show(error) }
            }
        }
    }

    private func presentEditor(
        image: CGImage,
        globalFrame: CGRect,
        context: CaptureContext?,
        workflowToken: CaptureWorkflowToken,
        initialTool: AnnotationTool? = nil,
        initialStyle: AnnotationStyle? = nil
    ) {
        guard workflowGate.isActive(workflowToken) else { return }
        let editor = AnnotationEditorController(
            image: image,
            globalFrame: globalFrame,
            context: context,
            initialTool: initialTool,
            initialStyle: initialStyle
        )
        editor.onClose = { [weak self] in
            self?.editorController = nil
            self?.finishWorkflow(workflowToken)
        }
        editor.onLongCapture = { [weak self] context in self?.startLongCapture(context) }
        editorController = editor
    }

    func startLongCapture(_ context: CaptureContext) {
        startLongCapture(context, workflowToken: nil)
    }

    private func startLongCapture(
        _ context: CaptureContext,
        workflowToken requestedToken: CaptureWorkflowToken?
    ) {
        guard longCaptureSession == nil else { return }
        let workflowToken: CaptureWorkflowToken
        if let requestedToken, workflowGate.isActive(requestedToken) {
            workflowToken = requestedToken
        } else if let acquiredToken = acquireWorkflow() {
            workflowToken = acquiredToken
        } else {
            return
        }
        let session = LongCaptureSession(context: context, service: service)
        session.onFinish = { [weak self] in
            self?.longCaptureSession = nil
            self?.finishWorkflow(workflowToken)
        }
        longCaptureSession = session
        session.start()
    }

    private func acquireWorkflow() -> CaptureWorkflowToken? {
        guard let token = workflowGate.acquire() else { return nil }
        _ = HotKeyManager.active?.register(
            id: escapeHotKeyID,
            keyCode: UInt32(kVK_Escape),
            modifiers: 0
        ) { [weak self] in
            self?.cancelActiveWorkflow()
        }
        return token
    }

    @discardableResult
    private func finishWorkflow(_ token: CaptureWorkflowToken) -> Bool {
        guard workflowGate.release(token) else { return false }
        captureTask = nil
        HotKeyManager.active?.unregister(id: escapeHotKeyID)
        return true
    }

    private func cancelActiveWorkflow() {
        guard let workflowToken = workflowGate.activeToken else { return }
        captureTask?.cancel()
        captureTask = nil
        if let selectionController {
            selectionController.cancel()
        } else if let editorController {
            editorController.close()
        } else if let longCaptureSession {
            longCaptureSession.cancel()
        } else {
            finishWorkflow(workflowToken)
        }
    }

    private func show(_ error: Error) {
        if let captureError = error as? CaptureServiceError,
           captureError.needsPermissionRecovery {
            showPermissionRecovery()
            return
        }
        let alert = NSAlert(error: error)
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func showPermissionRecovery() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "请在“隐私与安全性 → 屏幕与系统音频录制”中允许 Screen Capture。授权后返回应用即可重新检测。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ScreenCapturePermission.openSystemSettings()
        }
    }
}
