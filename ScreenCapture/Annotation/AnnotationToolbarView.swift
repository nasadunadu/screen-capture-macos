import SwiftUI

struct AnnotationToolbarView: View {
    static let primaryTools: [AnnotationTool] = [
        .rectangle, .ellipse, .line, .arrow, .pen, .text
    ]

    @ObservedObject var document: AnnotationDocument
    let supportsLongCapture: Bool
    let onLongCapture: () -> Void
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onCancel: () -> Void
    @State private var optionsTool: AnnotationTool?

    init(
        document: AnnotationDocument,
        supportsLongCapture: Bool,
        onLongCapture: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onSaveAs: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.document = document
        self.supportsLongCapture = supportsLongCapture
        self.onLongCapture = onLongCapture
        self.onSave = onSave
        self.onSaveAs = onSaveAs
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.primaryTools) { tool in toolButton(tool) }

            AnnotationGlobalColorControl(document: document)

            if supportsLongCapture {
                actionButton(
                    systemImage: "scroll",
                    help: "切换为滚动长截图",
                    action: onLongCapture
                )
            }

            actionButton(systemImage: "arrow.uturn.backward", help: "撤销 ⌘Z", action: document.undo)

            actionButton(systemImage: "xmark", help: "取消 Esc", action: onCancel)

            actionButton(systemImage: "arrow.down.to.line", help: "另存为", action: onSaveAs)

            Button(action: onSave) {
                Image(systemName: "checkmark")
                    .font(.system(size: 23, weight: .regular))
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("按默认动作完成 Return")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.28)))
        .shadow(color: .black.opacity(0.22), radius: 11, y: 5)
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        Button {
            let currentTool = document.tool
            if currentTool != tool {
                document.tool = tool
                document.selectedElementID = nil
            }
            optionsTool = Self.optionsToolAfterSelecting(
                tool,
                currentTool: currentTool,
                presentedTool: optionsTool
            )
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 42, height: 42)
                .background(document.tool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tool.hasStyleOptions ? "\(tool.title)；点击设置粗细和样式" : tool.title)
        .popover(isPresented: Binding(
            get: { optionsTool == tool },
            set: { if !$0, optionsTool == tool { optionsTool = nil } }
        ), arrowEdge: .bottom) {
            AnnotationStyleOptionsView(document: document, tool: tool)
        }
    }

    static func optionsToolAfterSelecting(
        _ tool: AnnotationTool,
        currentTool: AnnotationTool,
        presentedTool: AnnotationTool?
    ) -> AnnotationTool? {
        guard tool.hasStyleOptions else { return nil }
        if currentTool == tool, presentedTool == tool { return nil }
        return tool
    }

    private func actionButton(
        systemImage: String,
        help: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .help(help)
    }
}

private struct AnnotationGlobalColorControl: View {
    @ObservedObject var document: AnnotationDocument
    @State private var isPresented = false

    private let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .white, .black
    ]

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Circle()
                .fill(Color(nsColor: document.style.color))
                .overlay(Circle().stroke(.secondary, lineWidth: 1))
                .frame(width: 23, height: 23)
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("全局标注颜色")
        .accessibilityLabel("全局标注颜色")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("全局标注颜色")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        Button {
                            document.setColor(color)
                            isPresented = false
                        } label: {
                            Circle()
                                .fill(Color(nsColor: color))
                                .overlay {
                                    Circle().stroke(
                                        document.style.color.isEqual(color) ? Color.accentColor : Color.secondary.opacity(0.4),
                                        lineWidth: document.style.color.isEqual(color) ? 3 : 1
                                    )
                                }
                                .padding(3)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help(color.accessibilityName)
                        .accessibilityLabel(color.accessibilityName)
                    }
                }

                ColorPicker(
                    "自定义颜色",
                    selection: Binding(
                        get: { Color(nsColor: document.style.color) },
                        set: { document.setColor(NSColor($0)) }
                    ),
                    supportsOpacity: false
                )
            }
            .padding(14)
            .frame(width: 318)
        }
    }
}

private struct AnnotationStyleOptionsView: View {
    @ObservedObject var document: AnnotationDocument
    let tool: AnnotationTool

    private let commonColors: [NSColor] = [
        .systemRed, .systemPink, .systemBlue, .systemYellow, .systemGreen
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(tool.title)样式")
                .font(.headline)

            if tool.supportsLineWidth {
                HStack(spacing: 10) {
                    Text("粗细")
                    Slider(
                        value: Binding(
                            get: { Double(document.activeLineWidth) },
                            set: { document.setLineWidth(CGFloat($0)) }
                        ),
                        in: 1...18,
                        step: 1,
                        onEditingChanged: { isEditing in
                            isEditing ? document.beginLineWidthAdjustment() : document.endLineWidthAdjustment()
                        }
                    )
                    Text("\(Int(document.activeLineWidth.rounded())) px")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .frame(width: 46, alignment: .trailing)
                }

                Capsule(style: .continuous)
                    .fill(Color(nsColor: document.nextDrawingColor))
                    .frame(height: max(1, min(18, document.activeLineWidth)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .accessibilityHidden(true)

                Divider()

                HStack(spacing: 10) {
                    Text("本次颜色")

                    Spacer(minLength: 4)

                    ForEach(Array(commonColors.enumerated()), id: \.offset) { _, color in
                        Button {
                            document.setOneShotColor(color)
                        } label: {
                            Circle()
                                .fill(Color(nsColor: color))
                                .overlay {
                                    Circle().stroke(
                                        document.nextDrawingColor.isEqual(color)
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.35),
                                        lineWidth: document.nextDrawingColor.isEqual(color) ? 3 : 1
                                    )
                                }
                                .padding(3)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help("下一笔使用\(color.accessibilityName)")
                        .accessibilityLabel("下一笔使用\(color.accessibilityName)")
                    }

                    Button {
                        AnnotationColorPanelPresenter.shared.present(
                            color: document.nextDrawingColor,
                            onChange: { [weak document] color in
                                document?.setOneShotColor(color)
                            }
                        )
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(.white.opacity(0.75), lineWidth: 1)
                            }
                            .frame(width: 44, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("自由选择下一笔颜色")
                    .accessibilityLabel("自由选择下一笔颜色")
                }

                Text("仅影响下一次绘制，不改变工具条的全局默认色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if tool == .rectangle || tool == .ellipse {
                Divider()
                Toggle("形状填充", isOn: styleBinding(\.filled))
            } else if tool == .spotlight {
                Divider()
                Toggle("椭圆聚光", isOn: styleBinding(\.spotlightEllipse))
            }
        }
        .padding(14)
        .frame(width: 318)
    }

    private func styleBinding(_ keyPath: WritableKeyPath<AnnotationStyle, Bool>) -> Binding<Bool> {
        Binding(
            get: { document.style[keyPath: keyPath] },
            set: { document.style[keyPath: keyPath] = $0; document.objectWillChange.send() }
        )
    }
}

@MainActor
private final class AnnotationColorPanelPresenter: NSObject {
    static let shared = AnnotationColorPanelPresenter()

    private var onChange: ((NSColor) -> Void)?

    func present(color: NSColor, onChange: @escaping (NSColor) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.mode = .wheel
        panel.color = color
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

private extension AnnotationTool {
    var hasStyleOptions: Bool {
        supportsLineWidth || self == .spotlight
    }
}

private extension NSColor {
    var accessibilityName: String {
        if self == .systemRed { return "红色" }
        if self == .systemPink { return "粉色" }
        if self == .systemOrange { return "橙色" }
        if self == .systemYellow { return "黄色" }
        if self == .systemGreen { return "绿色" }
        if self == .systemBlue { return "蓝色" }
        if self == .systemPurple { return "紫色" }
        if self == .white { return "白色" }
        return "黑色"
    }
}
