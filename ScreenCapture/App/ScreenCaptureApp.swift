import SwiftUI

@main
struct ScreenCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra("Screen Capture", systemImage: "viewfinder") {
            Label("Screen Capture 已就绪", systemImage: "checkmark.circle.fill")

            Divider()

            Button("普通截图  \(settings.normalShortcut.displayName)") {
                CaptureCoordinator.shared.begin(.region)
            }
            Button("滚动截图  \(settings.longCaptureShortcut.displayName)") {
                CaptureCoordinator.shared.begin(.longCapture)
            }
            Button("窗口截图") { CaptureCoordinator.shared.begin(.window) }
            Button("全屏截图") { CaptureCoordinator.shared.begin(.fullScreen) }

            Divider()

            Button("上次区域") { CaptureCoordinator.shared.begin(.previousArea) }
            Button("预设尺寸 \(Int(settings.presetWidth)) × \(Int(settings.presetHeight))") {
                CaptureCoordinator.shared.begin(.presetArea)
            }
            Button("延时全屏 \(Int(settings.delaySeconds)) 秒") {
                CaptureCoordinator.shared.begin(.delayedFullScreen)
            }

            Divider()

            Button("设置…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            Button("退出 Screen Capture") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}
