import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var permissionGranted = ScreenCapturePermission.isGranted

    var body: some View {
        TabView {
            captureSettings
                .tabItem { Label("截图", systemImage: "viewfinder") }
            annotationSettings
                .tabItem { Label("标注", systemImage: "pencil.and.outline") }
            exportSettings
                .tabItem { Label("保存", systemImage: "square.and.arrow.down") }
            generalSettings
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 760, height: 560)
        .padding(14)
        .onAppear { refreshPermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermission()
        }
    }

    private var captureSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("截图模式与快捷键")
                .font(.headline)

            VStack(spacing: 0) {
                ShortcutTableHeader()
                Divider()
                ShortcutSettingsRow(
                    title: "普通截图",
                    shortcut: requiredShortcutBinding($settings.normalShortcut),
                    preference: "拖动选择截图区域"
                )
                ShortcutSettingsRow(
                    title: "窗口截图",
                    shortcut: $settings.windowShortcut,
                    preference: "自动识别光标窗口"
                )
                ShortcutSettingsRow(
                    title: "全屏截图",
                    shortcut: $settings.fullScreenShortcut,
                    preference: "当前显示器"
                )
                ShortcutSettingsRow(
                    title: "上次区域",
                    shortcut: $settings.previousAreaShortcut,
                    preference: "重复使用上次选区"
                )
                ShortcutSettingsRow(
                    title: "预设区域",
                    shortcut: $settings.presetAreaShortcut,
                    preference: "\(Int(settings.presetWidth)) × \(Int(settings.presetHeight))"
                )
                ShortcutSettingsRow(
                    title: "延时全屏",
                    shortcut: $settings.delayedFullScreenShortcut,
                    preference: "延时 \(Int(settings.delaySeconds)) 秒"
                )
                ShortcutSettingsRow(
                    title: "滚动长图",
                    shortcut: requiredShortcutBinding($settings.longCaptureShortcut),
                    preference: "选择区域后开始滚动"
                )
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.7)))

            HStack {
                Text("点击快捷键框后直接按组合键；Delete 清除，Esc 取消。修改后立即生效。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("重置") { settings.resetShortcuts() }
            }

            if settings.hasDuplicateShortcuts {
                Label("存在重复快捷键，请重新录入", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if let message = settings.shortcutRegistrationError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    Text("预设区域")
                        .frame(width: 110, alignment: .leading)
                    HStack {
                        TextField(
                            "宽",
                            value: Binding(
                                get: { settings.presetWidth },
                                set: { settings.setPresetWidth($0) }
                            ),
                            format: .number
                        )
                            .frame(width: 90)
                        Text("×")
                        TextField(
                            "高",
                            value: Binding(
                                get: { settings.presetHeight },
                                set: { settings.setPresetHeight($0) }
                            ),
                            format: .number
                        )
                            .frame(width: 90)
                        Text("pt").foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Text("延时全屏")
                    HStack {
                        Slider(
                            value: Binding(
                                get: { settings.delaySeconds },
                                set: { settings.setDelaySeconds($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                            .frame(width: 260)
                        Text("\(Int(settings.delaySeconds)) 秒")
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                GridRow {
                    Text("截图效果")
                    Toggle("截图中包含光标", isOn: $settings.captureCursor)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func requiredShortcutBinding(
        _ binding: Binding<KeyboardShortcutDefinition>
    ) -> Binding<KeyboardShortcutDefinition?> {
        Binding(
            get: { binding.wrappedValue },
            set: { value in
                if let value { binding.wrappedValue = value }
            }
        )
    }

    private var annotationSettings: some View {
        Form {
            Section("内置工具") {
                Text("矩形、椭圆、直线、箭头、画笔、文字、聚光高亮")
                    .foregroundStyle(.secondary)
                Text("工具快捷键：1–7 · 撤销：⌘Z · 重做：⇧⌘Z · 删除：⌫")
                    .foregroundStyle(.secondary)
            }
            Section("截图效果") {
                HStack {
                    Text("圆角")
                    Slider(
                        value: Binding(
                            get: { settings.cornerRadius },
                            set: { settings.setCornerRadius($0) }
                        ),
                        in: 0...32,
                        step: 1
                    )
                    Text("\(Int(settings.cornerRadius)) pt")
                        .frame(width: 48, alignment: .trailing)
                }
                Toggle("导出时添加阴影", isOn: $settings.shadowEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private var exportSettings: some View {
        Form {
            Section("完成动作") {
                Picker("默认动作", selection: $settings.defaultAction) {
                    ForEach(DefaultExportAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                Toggle("保存文件时同时复制到剪贴板", isOn: $settings.copyAfterSave)
                Toggle("完成时播放声音", isOn: $settings.playSound)
            }

            Section("图片") {
                Picker("格式", selection: $settings.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                if settings.format == .jpeg {
                    HStack {
                        Text("JPEG 质量")
                        Slider(
                            value: Binding(
                                get: { settings.jpegQuality },
                                set: { settings.setJPEGQuality($0) }
                            ),
                            in: 0.5...1
                        )
                        Text("\(Int(settings.jpegQuality * 100))%")
                    }
                }
            }

            Section("保存位置") {
                HStack {
                    Text(settings.saveDirectory)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("选择…") { settings.chooseSaveDirectory() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalSettings: some View {
        Form {
            Section("启动") {
                Toggle(
                    "登录时启动",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
            }

            Section("屏幕录制权限") {
                HStack {
                    Image(systemName: permissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(permissionGranted ? .green : .orange)
                    Text(permissionGranted ? "已授权" : "尚未授权")
                    Spacer()
                    Button("重新检测") { refreshPermission() }
                    Button("打开系统设置") { ScreenCapturePermission.openSystemSettings() }
                }
                Text("截图像素仅在本机内存、剪贴板和你选择的文件夹中处理。应用不包含网络上传功能。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "\(version) (Build \(build))"
        }
        return version
    }

    private func refreshPermission() {
        permissionGranted = ScreenCapturePermission.isGranted
    }
}

private struct ShortcutTableHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("截图模式")
                .frame(width: 170, alignment: .leading)
            Text("快捷键")
                .frame(width: 150, alignment: .center)
            Text("偏好设置")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 30)
    }
}

private struct ShortcutSettingsRow: View {
    let title: String
    @Binding var shortcut: KeyboardShortcutDefinition?
    let preference: String

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .frame(width: 170, alignment: .leading)
            ShortcutRecorderView(shortcut: $shortcut)
                .frame(width: 150, height: 30)
            Text(preference)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .contentShape(Rectangle())
    }
}
