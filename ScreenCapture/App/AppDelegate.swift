import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let captureShortcutIDs: ClosedRange<UInt32> = 1...7
    private var hotKeys: HotKeyManager?
    private var cancellables: Set<AnyCancellable> = []
    private var isRecordingShortcut = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyApplicationIcon()
        let manager = HotKeyManager()
        hotKeys = manager

        let primaryShortcuts = Publishers.CombineLatest4(
            AppSettings.shared.$normalShortcut,
            AppSettings.shared.$longCaptureShortcut,
            AppSettings.shared.$windowShortcut,
            AppSettings.shared.$fullScreenShortcut
        )
        let secondaryShortcuts = Publishers.CombineLatest3(
            AppSettings.shared.$previousAreaShortcut,
            AppSettings.shared.$presetAreaShortcut,
            AppSettings.shared.$delayedFullScreenShortcut
        )
        primaryShortcuts.combineLatest(secondaryShortcuts)
            .sink { [weak self] _ in self?.registerShortcuts() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .shortcutRecordingDidStart)
            .sink { [weak self] _ in
                self?.isRecordingShortcut = true
                self?.hotKeys?.unregister(ids: self?.captureShortcutIDs ?? 1...7)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .shortcutRecordingDidEnd)
            .sink { [weak self] _ in
                self?.isRecordingShortcut = false
                self?.registerShortcuts()
            }
            .store(in: &cancellables)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        ScreenCapturePermission.handleApplicationDidBecomeActive()
    }

    private func applyApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApp.applicationIconImage = icon
    }

    private func registerShortcuts() {
        guard !isRecordingShortcut else { return }
        hotKeys?.unregister(ids: captureShortcutIDs)
        let settings = AppSettings.shared
        var failures: [String] = []
        if !register(id: 1, shortcut: settings.normalShortcut, mode: .region) { failures.append(CaptureMode.region.title) }
        if !register(id: 2, shortcut: settings.longCaptureShortcut, mode: .longCapture) { failures.append(CaptureMode.longCapture.title) }
        if !register(id: 3, shortcut: settings.windowShortcut, mode: .window) { failures.append(CaptureMode.window.title) }
        if !register(id: 4, shortcut: settings.fullScreenShortcut, mode: .fullScreen) { failures.append(CaptureMode.fullScreen.title) }
        if !register(id: 5, shortcut: settings.previousAreaShortcut, mode: .previousArea) { failures.append(CaptureMode.previousArea.title) }
        if !register(id: 6, shortcut: settings.presetAreaShortcut, mode: .presetArea) { failures.append(CaptureMode.presetArea.title) }
        if !register(id: 7, shortcut: settings.delayedFullScreenShortcut, mode: .delayedFullScreen) { failures.append(CaptureMode.delayedFullScreen.title) }
        settings.setShortcutRegistrationFailures(failures)
    }

    private func register(id: UInt32, shortcut: KeyboardShortcutDefinition?, mode: CaptureMode) -> Bool {
        guard let shortcut else { return true }
        return hotKeys?.register(id: id, keyCode: shortcut.key.keyCode, modifiers: shortcut.modifiers) {
            CaptureCoordinator.shared.begin(mode)
        } ?? false
    }
}
