import AppKit
import XCTest
@testable import ScreenCapture

final class ImageExporterTests: XCTestCase {
    @MainActor
    func testCancellationDuringProcessingDoesNotWriteFileOrClipboard() async throws {
        let suite = "ScreenCaptureTests.Export.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettings(defaults: defaults)
        settings.saveDirectory = directory.path
        settings.defaultAction = .both
        let started = expectation(description: "Background image processing started")
        let resume = DispatchSemaphore(value: 0)
        var clipboardWrites = 0
        let exporter = ImageExporter(settings: settings, copyImage: { _ in clipboardWrites += 1 }, applyEffects: { image, _ in
            started.fulfill()
            _ = resume.wait(timeout: .now() + 5)
            return image
        })
        let image = try makeImage()
        let task = Task { try await exporter.performDefaultAction(image: image) }
        await fulfillment(of: [started], timeout: 5)
        task.cancel()
        resume.signal()
        do {
            _ = try await task.value
            XCTFail("Cancelled export must throw CancellationError")
        } catch is CancellationError {
        }
        XCTAssertEqual(clipboardWrites, 0)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @MainActor
    func testConcurrentExportsDoNotOverwriteOneAnother() async throws {
        let suite = "ScreenCaptureTests.Export.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettings(defaults: defaults)
        settings.saveDirectory = directory.path
        settings.defaultAction = .file
        settings.copyAfterSave = false
        let started = expectation(description: "Both exports are processing before either writes")
        started.expectedFulfillmentCount = 2
        let resume = DispatchSemaphore(value: 0)
        let exporter = ImageExporter(settings: settings, copyImage: { _ in XCTFail("Save only must not copy") }, applyEffects: { image, _ in
            started.fulfill()
            _ = resume.wait(timeout: .now() + 5)
            return image
        }, now: { Date(timeIntervalSince1970: 0) })
        let image = try makeImage()
        let first = Task { try await exporter.performDefaultAction(image: image) }
        let second = Task { try await exporter.performDefaultAction(image: image) }
        await fulfillment(of: [started], timeout: 5)
        resume.signal()
        resume.signal()
        let firstURL = try await first.value
        let secondURL = try await second.value
        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    private func makeImage() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 16,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try XCTUnwrap(context.makeImage())
    }

    func testClipboardPlanDoesNotWriteAFile() {
        XCTAssertEqual(
            ImageExportPlan.defaultAction(.clipboard, copyAfterSave: true),
            ImageExportPlan(writesFile: false, copiesToClipboard: true)
        )
    }

    func testFilePlanHonorsCopyAfterSave() {
        XCTAssertEqual(
            ImageExportPlan.defaultAction(.file, copyAfterSave: false),
            ImageExportPlan(writesFile: true, copiesToClipboard: false)
        )
        XCTAssertEqual(
            ImageExportPlan.defaultAction(.file, copyAfterSave: true),
            ImageExportPlan(writesFile: true, copiesToClipboard: true)
        )
    }

    func testSaveAndCopyPlanCopiesExactlyOnce() {
        XCTAssertEqual(
            ImageExportPlan.defaultAction(.both, copyAfterSave: true),
            ImageExportPlan(writesFile: true, copiesToClipboard: true)
        )
    }
}
