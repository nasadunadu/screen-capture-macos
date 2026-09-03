import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case region
    case window
    case fullScreen
    case previousArea
    case presetArea
    case delayedFullScreen
    case longCapture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .region: "区域截图"
        case .window: "窗口截图"
        case .fullScreen: "全屏截图"
        case .previousArea: "上次区域"
        case .presetArea: "预设尺寸"
        case .delayedFullScreen: "延时全屏"
        case .longCapture: "长截图"
        }
    }
}

struct ExportOptions: Sendable {
    let format: ExportFormat
    let jpegQuality: CGFloat
    let directoryURL: URL
    let copyAfterSave: Bool
    let playSound: Bool
    let cornerRadius: CGFloat
    let shadowEnabled: Bool
}
