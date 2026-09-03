import XCTest
@testable import ScreenCapture

final class AppSettingsValidationTests: XCTestCase {
    func testCorruptNumericPreferencesAreMadeSafe() {
        XCTAssertEqual(AppSettings.validDelaySeconds(.nan), 3)
        XCTAssertEqual(AppSettings.validDelaySeconds(-20), 1)
        XCTAssertEqual(AppSettings.validDelaySeconds(1_000), 10)
        XCTAssertEqual(AppSettings.validPresetDimension(.infinity), 400)
        XCTAssertEqual(AppSettings.validPresetDimension(-1), 16)
        XCTAssertEqual(AppSettings.validJPEGQuality(9), 1)
        XCTAssertEqual(AppSettings.validCornerRadius(-4), 0)
    }

    @MainActor
    func testInteractiveNumericSettingsStayBoundedAndPersistWithoutRecursion() throws {
        let suiteName = "ScreenCaptureTests.AppSettings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        for value in stride(from: 0.0, through: 32.0, by: 1.0) {
            settings.setCornerRadius(value)
        }
        settings.setJPEGQuality(0.75)
        settings.setDelaySeconds(7)
        settings.setPresetWidth(640)
        settings.setPresetHeight(480)

        XCTAssertEqual(settings.cornerRadius, 32)
        XCTAssertEqual(settings.jpegQuality, 0.75)
        XCTAssertEqual(settings.delaySeconds, 7)
        XCTAssertEqual(settings.presetWidth, 640)
        XCTAssertEqual(settings.presetHeight, 480)
        XCTAssertEqual(defaults.double(forKey: "cornerRadius"), 32)
        XCTAssertEqual(defaults.double(forKey: "jpegQuality"), 0.75)
        XCTAssertEqual(defaults.double(forKey: "delaySeconds"), 7)
        XCTAssertEqual(defaults.double(forKey: "presetWidth"), 640)
        XCTAssertEqual(defaults.double(forKey: "presetHeight"), 480)

        settings.setJPEGQuality(.infinity)
        settings.setDelaySeconds(-100)
        settings.setPresetWidth(.nan)
        settings.setPresetHeight(100_000)
        settings.setCornerRadius(-10)

        XCTAssertEqual(settings.jpegQuality, 0.92)
        XCTAssertEqual(settings.delaySeconds, 1)
        XCTAssertEqual(settings.presetWidth, 400)
        XCTAssertEqual(settings.presetHeight, 10_000)
        XCTAssertEqual(settings.cornerRadius, 0)
    }

    @MainActor
    func testSettingsPageValuesRoundTripThroughIsolatedDefaults() throws {
        let suiteName = "ScreenCaptureTests.AppSettings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let windowShortcut = KeyboardShortcutDefinition(
            key: ShortcutKeyOption.supported[7],
            modifiers: KeyboardShortcutDefinition.normalDefault.modifiers
        )

        settings.format = .jpeg
        settings.saveDirectory = "/tmp/ScreenCaptureTests"
        settings.copyAfterSave = false
        settings.playSound = true
        settings.captureCursor = true
        settings.shadowEnabled = true
        settings.defaultAction = .both
        settings.windowShortcut = windowShortcut

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.format, .jpeg)
        XCTAssertEqual(reloaded.saveDirectory, "/tmp/ScreenCaptureTests")
        XCTAssertFalse(reloaded.copyAfterSave)
        XCTAssertTrue(reloaded.playSound)
        XCTAssertTrue(reloaded.captureCursor)
        XCTAssertTrue(reloaded.shadowEnabled)
        XCTAssertEqual(reloaded.defaultAction, .both)
        XCTAssertEqual(reloaded.windowShortcut, windowShortcut)
    }

    @MainActor
    func testShortcutResetAndDuplicateDetectionRemainSafe() throws {
        let suiteName = "ScreenCaptureTests.AppSettings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        settings.windowShortcut = settings.normalShortcut
        XCTAssertTrue(settings.hasDuplicateShortcuts)
        settings.setShortcutRegistrationFailures(["窗口截图"])
        XCTAssertNotNil(settings.shortcutRegistrationError)

        settings.resetShortcuts()
        settings.setShortcutRegistrationFailures([])
        XCTAssertFalse(settings.hasDuplicateShortcuts)
        XCTAssertNil(settings.windowShortcut)
        XCTAssertNil(settings.fullScreenShortcut)
        XCTAssertNil(settings.previousAreaShortcut)
        XCTAssertNil(settings.presetAreaShortcut)
        XCTAssertNil(settings.delayedFullScreenShortcut)
        XCTAssertNil(settings.shortcutRegistrationError)
    }
}
