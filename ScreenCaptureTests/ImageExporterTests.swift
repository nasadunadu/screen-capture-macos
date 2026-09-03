import XCTest
@testable import ScreenCapture

final class ImageExporterTests: XCTestCase {
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
