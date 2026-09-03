import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ImageExportPlan: Equatable {
    let writesFile: Bool
    let copiesToClipboard: Bool

    static func defaultAction(
        _ action: DefaultExportAction,
        copyAfterSave: Bool
    ) -> ImageExportPlan {
        switch action {
        case .clipboard:
            ImageExportPlan(writesFile: false, copiesToClipboard: true)
        case .file:
            ImageExportPlan(writesFile: true, copiesToClipboard: copyAfterSave)
        case .both:
            ImageExportPlan(writesFile: true, copiesToClipboard: true)
        }
    }
}

@MainActor
final class ImageExporter {
    static let shared = ImageExporter()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    func performDefaultAction(image: CGImage) async throws -> URL? {
        let settings = AppSettings.shared
        let options = settings.exportOptions
        let plan = ImageExportPlan.defaultAction(
            settings.defaultAction,
            copyAfterSave: options.copyAfterSave
        )
        let destination = plan.writesFile ? nextAvailableURL(options: options) : nil
        let processed = try await process(image, options: options, destination: destination)

        if plan.copiesToClipboard { copyProcessedImage(processed) }
        playSoundIfNeeded(options: options)
        return destination
    }

    func saveAs(image: CGImage) async throws -> URL? {
        let options = AppSettings.shared.exportOptions
        let panel = NSSavePanel()
        panel.allowedContentTypes = [options.format == .png ? .png : .jpeg]
        panel.nameFieldStringValue = defaultFilename(options: options)
        panel.directoryURL = options.directoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        _ = try await process(image, options: options, destination: url)
        playSoundIfNeeded(options: options)
        return url
    }

    private func process(
        _ image: CGImage,
        options: ExportOptions,
        destination: URL?
    ) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let processed = ImageEffects.apply(to: image, options: options)
            if let destination {
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try Self.encodedData(for: processed, options: options)
                try Task.checkCancellation()
                try data.write(to: destination, options: .atomic)
            }
            return processed
        }.value
    }

    private func copyProcessedImage(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)])
    }

    private func nextAvailableURL(options: ExportOptions) -> URL {
        let baseName = "ScreenCapture_\(formatter.string(from: Date()))"
        var url = options.directoryURL
            .appendingPathComponent(baseName)
            .appendingPathExtension(options.format.fileExtension)
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = options.directoryURL
                .appendingPathComponent("\(baseName)_\(suffix)")
                .appendingPathExtension(options.format.fileExtension)
            suffix += 1
        }
        return url
    }

    private func defaultFilename(options: ExportOptions) -> String {
        "ScreenCapture_\(formatter.string(from: Date())).\(options.format.fileExtension)"
    }

    nonisolated private static func encodedData(
        for image: CGImage,
        options: ExportOptions
    ) throws -> Data {
        let data = NSMutableData()
        let type: UTType = options.format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithData(
            data,
            type.identifier as CFString,
            1,
            nil
        ) else { throw ExportError.encodingFailed }

        let properties: CFDictionary?
        switch options.format {
        case .png:
            properties = nil
        case .jpeg:
            properties = [
                kCGImageDestinationLossyCompressionQuality: options.jpegQuality
            ] as CFDictionary
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.encodingFailed
        }
        return data as Data
    }

    private func playSoundIfNeeded(options: ExportOptions) {
        guard options.playSound else { return }
        NSSound(named: "Glass")?.play()
    }
}

enum ExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? { "无法编码截图图片。" }
}
