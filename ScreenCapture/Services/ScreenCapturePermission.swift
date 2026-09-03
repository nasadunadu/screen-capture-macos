import AppKit
import CoreGraphics
import Foundation

enum ScreenCapturePermission {
    @MainActor private static var runtimeAccessConfirmed = false
    @MainActor private static var awaitingSystemSettingsReturn = false

    static let systemSettingsURLs = [
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"),
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    ].compactMap { $0 }

    @MainActor static var isGranted: Bool {
        runtimeAccessConfirmed || CGPreflightScreenCaptureAccess()
    }

    @MainActor
    @discardableResult
    static func request() -> Bool {
        isGranted || CGRequestScreenCaptureAccess()
    }

    @MainActor
    static func markAccessConfirmed() {
        runtimeAccessConfirmed = true
    }

    @MainActor
    static func openSystemSettings() {
        awaitingSystemSettingsReturn = true
        for url in systemSettingsURLs where NSWorkspace.shared.open(url) {
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    @MainActor
    static func handleApplicationDidBecomeActive() {
        guard awaitingSystemSettingsReturn else { return }
        awaitingSystemSettingsReturn = false
        guard !isGranted else { return }
        relaunch()
    }

    @MainActor
    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
