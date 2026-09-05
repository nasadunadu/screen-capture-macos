import XCTest
@testable import ScreenCapture

final class ShortcutObservationTests: XCTestCase {
    @MainActor
    func testRegistrationReadsNewValueAndResetClearsLastShortcut() async throws {
        let suite = "ScreenCaptureTests.ShortcutObservation.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        var observed: KeyboardShortcutDefinition?
        let observation = AppDelegate.observeShortcuts(settings: settings) {
            observed = settings.delayedFullScreenShortcut
        }
        defer { observation.cancel() }

        settings.delayedFullScreenShortcut = .longCaptureDefault
        await drainMainQueue()
        XCTAssertEqual(observed, .longCaptureDefault)

        settings.resetShortcuts()
        await drainMainQueue()
        XCTAssertNil(observed, "Reset must unregister the last optional shortcut too")
    }

    @MainActor private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
