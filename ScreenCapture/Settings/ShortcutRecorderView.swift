import AppKit
import SwiftUI

extension Notification.Name {
    static let shortcutRecordingDidStart = Notification.Name("shortcutRecordingDidStart")
    static let shortcutRecordingDidEnd = Notification.Name("shortcutRecordingDidEnd")
}

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutDefinition?

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = { shortcut = $0 }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = { shortcut = $0 }
        button.shortcut = shortcut
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onChange: ((KeyboardShortcutDefinition?) -> Void)?
    var shortcut: KeyboardShortcutDefinition? {
        didSet { refreshTitle() }
    }

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        controlSize = .large
        font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        target = self
        action = #selector(toggleRecording)
        focusRingType = .default
        refreshTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            isRecording = true
            title = "请按快捷键…"
            NotificationCenter.default.post(name: .shortcutRecordingDidStart, object: self)
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            stopRecording()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            onChange?(nil)
            stopRecording()
            return
        }
        guard let definition = KeyboardShortcutDefinition(event: event) else {
            NSSound.beep()
            return
        }
        onChange?(definition)
        stopRecording()
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording { stopRecording() }
        return result
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        refreshTitle()
        NotificationCenter.default.post(name: .shortcutRecordingDidEnd, object: self)
    }

    private func refreshTitle() {
        guard !isRecording else { return }
        title = shortcut?.displayName ?? "点击录入"
        toolTip = "点击后按下组合键；按 Delete 清除，按 Esc 取消"
    }
}
