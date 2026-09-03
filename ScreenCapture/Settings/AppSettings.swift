import AppKit
import Foundation
import ServiceManagement

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg

    var id: String { rawValue }
    var title: String { self == .png ? "PNG" : "JPEG" }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

enum DefaultExportAction: String, CaseIterable, Identifiable, Sendable {
    case clipboard
    case file
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "复制到剪贴板"
        case .file: "保存到文件"
        case .both: "保存并复制"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let format = "exportFormat"
        static let jpegQuality = "jpegQuality"
        static let saveDirectory = "saveDirectory"
        static let copyAfterSave = "copyAfterSave"
        static let playSound = "playSound"
        static let captureCursor = "captureCursor"
        static let cornerRadius = "cornerRadius"
        static let shadowEnabled = "shadowEnabled"
        static let delaySeconds = "delaySeconds"
        static let presetWidth = "presetWidth"
        static let presetHeight = "presetHeight"
        static let defaultAction = "defaultAction"
        static let normalShortcut = "normalShortcut"
        static let longCaptureShortcut = "longCaptureShortcut"
        static let windowShortcut = "windowShortcut"
        static let fullScreenShortcut = "fullScreenShortcut"
        static let previousAreaShortcut = "previousAreaShortcut"
        static let presetAreaShortcut = "presetAreaShortcut"
        static let delayedFullScreenShortcut = "delayedFullScreenShortcut"
    }

    @Published var format: ExportFormat { didSet { defaults.set(format.rawValue, forKey: Key.format) } }
    @Published private(set) var jpegQuality: Double
    @Published var saveDirectory: String { didSet { defaults.set(saveDirectory, forKey: Key.saveDirectory) } }
    @Published var copyAfterSave: Bool { didSet { defaults.set(copyAfterSave, forKey: Key.copyAfterSave) } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: Key.playSound) } }
    @Published var captureCursor: Bool { didSet { defaults.set(captureCursor, forKey: Key.captureCursor) } }
    @Published private(set) var cornerRadius: Double
    @Published var shadowEnabled: Bool { didSet { defaults.set(shadowEnabled, forKey: Key.shadowEnabled) } }
    @Published private(set) var delaySeconds: Double
    @Published private(set) var presetWidth: Double
    @Published private(set) var presetHeight: Double
    @Published var defaultAction: DefaultExportAction { didSet { defaults.set(defaultAction.rawValue, forKey: Key.defaultAction) } }
    @Published var normalShortcut: KeyboardShortcutDefinition {
        didSet { saveShortcut(normalShortcut, forKey: Key.normalShortcut) }
    }
    @Published var longCaptureShortcut: KeyboardShortcutDefinition {
        didSet { saveShortcut(longCaptureShortcut, forKey: Key.longCaptureShortcut) }
    }
    @Published var windowShortcut: KeyboardShortcutDefinition? {
        didSet { saveOptionalShortcut(windowShortcut, forKey: Key.windowShortcut) }
    }
    @Published var fullScreenShortcut: KeyboardShortcutDefinition? {
        didSet { saveOptionalShortcut(fullScreenShortcut, forKey: Key.fullScreenShortcut) }
    }
    @Published var previousAreaShortcut: KeyboardShortcutDefinition? {
        didSet { saveOptionalShortcut(previousAreaShortcut, forKey: Key.previousAreaShortcut) }
    }
    @Published var presetAreaShortcut: KeyboardShortcutDefinition? {
        didSet { saveOptionalShortcut(presetAreaShortcut, forKey: Key.presetAreaShortcut) }
    }
    @Published var delayedFullScreenShortcut: KeyboardShortcutDefinition? {
        didSet { saveOptionalShortcut(delayedFullScreenShortcut, forKey: Key.delayedFullScreenShortcut) }
    }
    @Published private(set) var launchAtLogin = false
    @Published private(set) var shortcutRegistrationError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        format = ExportFormat(rawValue: defaults.string(forKey: Key.format) ?? "png") ?? .png
        jpegQuality = Self.validJPEGQuality(defaults.object(forKey: Key.jpegQuality) as? Double ?? 0.92)
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        saveDirectory = defaults.string(forKey: Key.saveDirectory) ?? downloads.path
        copyAfterSave = defaults.object(forKey: Key.copyAfterSave) as? Bool ?? true
        playSound = defaults.object(forKey: Key.playSound) as? Bool ?? false
        captureCursor = defaults.object(forKey: Key.captureCursor) as? Bool ?? false
        cornerRadius = Self.validCornerRadius(defaults.object(forKey: Key.cornerRadius) as? Double ?? 0)
        shadowEnabled = defaults.object(forKey: Key.shadowEnabled) as? Bool ?? false
        delaySeconds = Self.validDelaySeconds(defaults.object(forKey: Key.delaySeconds) as? Double ?? 3)
        presetWidth = Self.validPresetDimension(defaults.object(forKey: Key.presetWidth) as? Double ?? 400)
        presetHeight = Self.validPresetDimension(defaults.object(forKey: Key.presetHeight) as? Double ?? 300)
        defaultAction = DefaultExportAction(rawValue: defaults.string(forKey: Key.defaultAction) ?? "clipboard") ?? .clipboard
        normalShortcut = Self.loadShortcut(
            from: defaults,
            key: Key.normalShortcut,
            fallback: .normalDefault
        )
        longCaptureShortcut = Self.loadShortcut(
            from: defaults,
            key: Key.longCaptureShortcut,
            fallback: .longCaptureDefault
        )
        windowShortcut = Self.loadOptionalShortcut(from: defaults, key: Key.windowShortcut)
        fullScreenShortcut = Self.loadOptionalShortcut(from: defaults, key: Key.fullScreenShortcut)
        previousAreaShortcut = Self.loadOptionalShortcut(from: defaults, key: Key.previousAreaShortcut)
        presetAreaShortcut = Self.loadOptionalShortcut(from: defaults, key: Key.presetAreaShortcut)
        delayedFullScreenShortcut = Self.loadOptionalShortcut(from: defaults, key: Key.delayedFullScreenShortcut)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setJPEGQuality(_ value: Double) {
        let validated = Self.validJPEGQuality(value)
        guard jpegQuality != validated else { return }
        jpegQuality = validated
        defaults.set(validated, forKey: Key.jpegQuality)
    }

    func setCornerRadius(_ value: Double) {
        let validated = Self.validCornerRadius(value)
        guard cornerRadius != validated else { return }
        cornerRadius = validated
        defaults.set(validated, forKey: Key.cornerRadius)
    }

    func setDelaySeconds(_ value: Double) {
        let validated = Self.validDelaySeconds(value)
        guard delaySeconds != validated else { return }
        delaySeconds = validated
        defaults.set(validated, forKey: Key.delaySeconds)
    }

    func setPresetWidth(_ value: Double) {
        let validated = Self.validPresetDimension(value)
        guard presetWidth != validated else { return }
        presetWidth = validated
        defaults.set(validated, forKey: Key.presetWidth)
    }

    func setPresetHeight(_ value: Double) {
        let validated = Self.validPresetDimension(value)
        guard presetHeight != validated else { return }
        presetHeight = validated
        defaults.set(validated, forKey: Key.presetHeight)
    }

    var exportOptions: ExportOptions {
        ExportOptions(
            format: format,
            jpegQuality: CGFloat(jpegQuality),
            directoryURL: URL(fileURLWithPath: saveDirectory, isDirectory: true),
            copyAfterSave: copyAfterSave,
            playSound: playSound,
            cornerRadius: CGFloat(cornerRadius),
            shadowEnabled: shadowEnabled
        )
    }

    nonisolated static func validJPEGQuality(_ value: Double) -> Double {
        validated(value, in: 0.5...1, fallback: 0.92)
    }

    nonisolated static func validCornerRadius(_ value: Double) -> Double {
        validated(value, in: 0...64, fallback: 0)
    }

    nonisolated static func validDelaySeconds(_ value: Double) -> Double {
        validated(value, in: 1...10, fallback: 3)
    }

    nonisolated static func validPresetDimension(_ value: Double) -> Double {
        validated(value, in: 16...10_000, fallback: 400)
    }

    private nonisolated static func validated(
        _ value: Double,
        in range: ClosedRange<Double>,
        fallback: Double
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            NSSound.beep()
        }
    }

    func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: saveDirectory, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url.path
        }
    }

    func resetShortcuts() {
        normalShortcut = .normalDefault
        longCaptureShortcut = .longCaptureDefault
        windowShortcut = nil
        fullScreenShortcut = nil
        previousAreaShortcut = nil
        presetAreaShortcut = nil
        delayedFullScreenShortcut = nil
    }

    func setShortcutRegistrationFailures(_ modeNames: [String]) {
        shortcutRegistrationError = modeNames.isEmpty
            ? nil
            : "以下快捷键与系统或其他应用冲突：\(modeNames.joined(separator: "、"))"
    }

    var hasDuplicateShortcuts: Bool {
        let shortcuts = [
            normalShortcut,
            longCaptureShortcut,
            windowShortcut,
            fullScreenShortcut,
            previousAreaShortcut,
            presetAreaShortcut,
            delayedFullScreenShortcut
        ].compactMap { $0 }
        return Set(shortcuts).count != shortcuts.count
    }

    private func saveShortcut(_ shortcut: KeyboardShortcutDefinition, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
    }

    private func saveOptionalShortcut(_ shortcut: KeyboardShortcutDefinition?, forKey key: String) {
        guard let shortcut else {
            defaults.removeObject(forKey: key)
            return
        }
        saveShortcut(shortcut, forKey: key)
    }

    private static func loadShortcut(
        from defaults: UserDefaults,
        key: String,
        fallback: KeyboardShortcutDefinition
    ) -> KeyboardShortcutDefinition {
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data) else {
            return fallback
        }
        return shortcut
    }

    private static func loadOptionalShortcut(
        from defaults: UserDefaults,
        key: String
    ) -> KeyboardShortcutDefinition? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyboardShortcutDefinition.self, from: data)
    }
}
