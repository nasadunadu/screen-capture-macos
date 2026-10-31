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
    @State private var hoveredItem: String?

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
        HStack(spacing: 3.5) {
            HStack(spacing: 1.5) {
                ForEach(Self.primaryTools) { tool in
                    toolButton(tool)
                }
            }

            toolbarDivider

            HStack(spacing: 1.5) {
                AnnotationGlobalColorControl(
                    document: document,
                    isHovered: hoveredItem == "color",
                    onHoverChange: { updateHover("color", isHovering: $0) }
                )

                if supportsLongCapture {
                    actionButton(
                        id: "longCapture",
                        icon: .longCapture,
                        help: "切换为滚动长截图",
                        action: onLongCapture
                    )
                }
            }

            toolbarDivider

            HStack(spacing: 1.5) {
                actionButton(
                    id: "undo",
                    icon: .undo,
                    help: "撤销 ⌘Z",
                    isEnabled: document.canUndo,
                    action: document.undo
                )

                actionButton(
                    id: "saveAs",
                    icon: .saveAs,
                    help: "另存为",
                    action: onSaveAs
                )

                actionButton(
                    id: "cancel",
                    icon: .cancel,
                    help: "取消 Esc",
                    isDestructiveHover: true,
                    action: onCancel
                )
            }

            confirmButton
        }
        .padding(.horizontal, 5.5)
        .padding(.vertical, 4.5)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.black.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11.5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.20), radius: 12, y: 5)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.13))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 0.5)
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let isSelected = document.tool == tool
        let isHovered = hoveredItem == tool.id

        return Button {
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
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.16)
                            : (isHovered ? Color.primary.opacity(0.07) : Color.clear)
                    )
                if isSelected {
                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.42), lineWidth: 1)
                }

                ToolbarVectorIcon(kind: .tool(tool), isActive: isSelected)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.86))

                if isSelected {
                    VStack {
                        Spacer()
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 1.8)
                            .padding(.bottom, 2.5)
                    }
                }
            }
            .frame(width: 31, height: 31)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { updateHover(tool.id, isHovering: $0) }
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
        id: String,
        icon: ToolbarVectorIcon.Kind,
        help: String,
        isEnabled: Bool = true,
        isDestructiveHover: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredItem == id && isEnabled
        return Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(
                        isHovered
                            ? (isDestructiveHover ? Color.red.opacity(0.12) : Color.primary.opacity(0.07))
                            : Color.clear
                    )
                ToolbarVectorIcon(kind: icon, isActive: false)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(
                        isHovered && isDestructiveHover
                            ? Color.red
                            : Color.primary.opacity(0.86)
                    )
            }
            .frame(width: 31, height: 31)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.30)
        .onHover { updateHover(id, isHovering: $0) }
        .help(help)
    }

    private var confirmButton: some View {
        let isHovered = hoveredItem == "confirm"
        return Button(action: onSave) {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.37, green: 0.29, blue: 0.93).opacity(isHovered ? 1.0 : 0.92),
                                Color(red: 0.29, green: 0.21, blue: 0.84).opacity(isHovered ? 1.0 : 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)

                ToolbarVectorIcon(kind: .confirm, isActive: true)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Color.white)
            }
            .frame(width: 33, height: 31)
            .contentShape(Rectangle())
            .shadow(color: Color(red: 0.35, green: 0.27, blue: 0.91).opacity(0.28), radius: 4, y: 1.5)
        }
        .buttonStyle(.plain)
        .onHover { updateHover("confirm", isHovering: $0) }
        .help("按默认动作完成 Return")
    }

    private func updateHover(_ id: String, isHovering: Bool) {
        if isHovering {
            hoveredItem = id
        } else if hoveredItem == id {
            hoveredItem = nil
        }
    }
}

private struct ToolbarVectorIcon: View {
    enum Kind: Equatable {
        case tool(AnnotationTool)
        case longCapture
        case undo
        case saveAs
        case cancel
        case confirm
    }

    let kind: Kind
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineWidth: CGFloat = isActive ? 1.75 : 1.55
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let shading: GraphicsContext.Shading = .foreground

            switch kind {
            case .tool(.rectangle), .tool(.select), .tool(.spotlight):
                let rect = CGRect(x: 2.2, y: 3.4, width: w - 4.4, height: h - 6.8)
                let rounded = Path(roundedRect: rect, cornerRadius: 2.6, style: .continuous)
                context.stroke(rounded, with: shading, style: style)
                let corners = [
                    CGPoint(x: rect.minX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.minY),
                    CGPoint(x: rect.minX, y: rect.maxY),
                    CGPoint(x: rect.maxX, y: rect.maxY)
                ]
                for pt in corners {
                    let dot = CGRect(x: pt.x - 1.35, y: pt.y - 1.35, width: 2.7, height: 2.7)
                    context.fill(Path(ellipseIn: dot), with: shading)
                }

            case .tool(.ellipse):
                let rect = CGRect(x: 1.8, y: 3.3, width: w - 3.6, height: h - 6.6)
                context.stroke(Path(ellipseIn: rect), with: shading, style: style)

            case .tool(.line):
                let p1 = CGPoint(x: 3.6, y: h - 3.6)
                let p2 = CGPoint(x: w - 3.6, y: 3.6)
                var line = Path()
                line.move(to: CGPoint(x: p1.x + 1.3, y: p1.y - 1.3))
                line.addLine(to: CGPoint(x: p2.x - 1.3, y: p2.y + 1.3))
                context.stroke(line, with: shading, style: style)
                for pt in [p1, p2] {
                    let node = CGRect(x: pt.x - 1.9, y: pt.y - 1.9, width: 3.8, height: 3.8)
                    context.stroke(Path(ellipseIn: node), with: shading, style: StrokeStyle(lineWidth: 1.35))
                }

            case .tool(.arrow):
                let start = CGPoint(x: 3.4, y: h - 3.4)
                let end = CGPoint(x: w - 3.2, y: 3.2)
                var shaft = Path()
                shaft.move(to: start)
                shaft.addLine(to: end)
                context.stroke(shaft, with: shading, style: style)

                var head = Path()
                head.move(to: CGPoint(x: end.x - 6.2, y: end.y))
                head.addLine(to: end)
                head.addLine(to: CGPoint(x: end.x, y: end.y + 6.2))
                context.stroke(head, with: shading, style: style)

                let tailDot = CGRect(x: start.x - 1.4, y: start.y - 1.4, width: 2.8, height: 2.8)
                context.fill(Path(ellipseIn: tailDot), with: shading)

            case .tool(.pen):
                var penBody = Path()
                penBody.move(to: CGPoint(x: 11.8, y: 2.6))
                penBody.addLine(to: CGPoint(x: 15.2, y: 6.0))
                penBody.addLine(to: CGPoint(x: 7.4, y: 13.8))
                penBody.addLine(to: CGPoint(x: 3.2, y: 14.8))
                penBody.addLine(to: CGPoint(x: 4.2, y: 10.6))
                penBody.closeSubpath()
                context.stroke(penBody, with: shading, style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))

                var wave = Path()
                wave.move(to: CGPoint(x: 9.8, y: 14.8))
                wave.addCurve(
                    to: CGPoint(x: 15.6, y: 14.8),
                    control1: CGPoint(x: 11.6, y: 12.8),
                    control2: CGPoint(x: 13.8, y: 16.6)
                )
                context.stroke(wave, with: shading, style: StrokeStyle(lineWidth: 1.45, lineCap: .round))

            case .tool(.text):
                var serifT = Path()
                serifT.move(to: CGPoint(x: 2.8, y: 4.0))
                serifT.addLine(to: CGPoint(x: 11.6, y: 4.0))
                serifT.move(to: CGPoint(x: 2.8, y: 4.0))
                serifT.addLine(to: CGPoint(x: 2.8, y: 5.7))
                serifT.move(to: CGPoint(x: 11.6, y: 4.0))
                serifT.addLine(to: CGPoint(x: 11.6, y: 5.7))
                serifT.move(to: CGPoint(x: 7.2, y: 4.0))
                serifT.addLine(to: CGPoint(x: 7.2, y: 14.2))
                serifT.move(to: CGPoint(x: 5.3, y: 14.2))
                serifT.addLine(to: CGPoint(x: 9.1, y: 14.2))
                context.stroke(serifT, with: shading, style: style)

                var cursor = Path()
                cursor.move(to: CGPoint(x: 14.6, y: 3.2))
                cursor.addLine(to: CGPoint(x: 14.6, y: 14.8))
                cursor.move(to: CGPoint(x: 13.3, y: 3.2))
                cursor.addLine(to: CGPoint(x: 15.9, y: 3.2))
                cursor.move(to: CGPoint(x: 13.3, y: 14.8))
                cursor.addLine(to: CGPoint(x: 15.9, y: 14.8))
                context.stroke(cursor, with: shading, style: StrokeStyle(lineWidth: 1.35, lineCap: .round))

            case .longCapture:
                var brackets = Path()
                // Top and bottom panoramic frame brackets
                brackets.move(to: CGPoint(x: 3.0, y: 5.2))
                brackets.addLine(to: CGPoint(x: 3.0, y: 3.2))
                brackets.addLine(to: CGPoint(x: 6.2, y: 3.2))

                brackets.move(to: CGPoint(x: w - 6.2, y: 3.2))
                brackets.addLine(to: CGPoint(x: w - 3.0, y: 3.2))
                brackets.addLine(to: CGPoint(x: w - 3.0, y: 5.2))

                brackets.move(to: CGPoint(x: 3.0, y: h - 5.2))
                brackets.addLine(to: CGPoint(x: 3.0, y: h - 3.2))
                brackets.addLine(to: CGPoint(x: 6.2, y: h - 3.2))

                brackets.move(to: CGPoint(x: w - 6.2, y: h - 3.2))
                brackets.addLine(to: CGPoint(x: w - 3.0, y: h - 3.2))
                brackets.addLine(to: CGPoint(x: w - 3.0, y: h - 5.2))
                context.stroke(brackets, with: shading, style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))

                // Center downward scroll arrow + double chevron
                var arrow = Path()
                arrow.move(to: CGPoint(x: w / 2, y: 4.8))
                arrow.addLine(to: CGPoint(x: w / 2, y: 11.8))
                arrow.move(to: CGPoint(x: w / 2 - 2.9, y: 9.4))
                arrow.addLine(to: CGPoint(x: w / 2, y: 12.3))
                arrow.addLine(to: CGPoint(x: w / 2 + 2.9, y: 9.4))

                arrow.move(to: CGPoint(x: w / 2 - 2.9, y: 12.6))
                arrow.addLine(to: CGPoint(x: w / 2, y: 15.1))
                arrow.addLine(to: CGPoint(x: w / 2 + 2.9, y: 12.6))
                context.stroke(arrow, with: shading, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            case .undo:
                var path = Path()
                path.move(to: CGPoint(x: 6.8, y: 4.2))
                path.addLine(to: CGPoint(x: 3.4, y: 7.4))
                path.addLine(to: CGPoint(x: 6.8, y: 10.6))
                path.move(to: CGPoint(x: 3.8, y: 7.4))
                path.addLine(to: CGPoint(x: 10.6, y: 7.4))
                path.addArc(
                    center: CGPoint(x: 10.6, y: 11.1),
                    radius: 3.7,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(90),
                    clockwise: false
                )
                path.addLine(to: CGPoint(x: 6.2, y: 14.8))
                context.stroke(path, with: shading, style: style)

            case .saveAs:
                var tray = Path()
                tray.move(to: CGPoint(x: w / 2, y: 3.0))
                tray.addLine(to: CGPoint(x: w / 2, y: 11.6))
                tray.move(to: CGPoint(x: w / 2 - 3.3, y: 8.6))
                tray.addLine(to: CGPoint(x: w / 2, y: 11.9))
                tray.addLine(to: CGPoint(x: w / 2 + 3.3, y: 8.6))

                tray.move(to: CGPoint(x: 3.2, y: 11.4))
                tray.addLine(to: CGPoint(x: 3.2, y: 14.0))
                tray.addQuadCurve(
                    to: CGPoint(x: 4.8, y: 15.2),
                    control: CGPoint(x: 3.2, y: 15.2)
                )
                tray.addLine(to: CGPoint(x: w - 4.8, y: 15.2))
                tray.addQuadCurve(
                    to: CGPoint(x: w - 3.2, y: 14.0),
                    control: CGPoint(x: w - 3.2, y: 15.2)
                )
                tray.addLine(to: CGPoint(x: w - 3.2, y: 11.4))
                context.stroke(tray, with: shading, style: style)

            case .cancel:
                var cross = Path()
                cross.move(to: CGPoint(x: 4.6, y: 4.6))
                cross.addLine(to: CGPoint(x: w - 4.6, y: h - 4.6))
                cross.move(to: CGPoint(x: w - 4.6, y: 4.6))
                cross.addLine(to: CGPoint(x: 4.6, y: h - 4.6))
                context.stroke(cross, with: shading, style: style)

            case .confirm:
                var check = Path()
                check.move(to: CGPoint(x: 3.6, y: 9.4))
                check.addLine(to: CGPoint(x: 7.5, y: 13.3))
                check.addLine(to: CGPoint(x: 14.6, y: 4.8))
                context.stroke(
                    check,
                    with: shading,
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

private struct AnnotationGlobalColorControl: View {
    @ObservedObject var document: AnnotationDocument
    let isHovered: Bool
    let onHoverChange: (Bool) -> Void
    @State private var isPresented = false

    private let colors: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemPurple, .white, .black
    ]

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(isHovered || isPresented ? Color.primary.opacity(0.07) : Color.clear)

                Circle()
                    .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.15)
                    .frame(width: 19, height: 19)

                Circle()
                    .fill(Color(nsColor: document.style.color))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75)
                    }
                    .shadow(color: Color(nsColor: document.style.color).opacity(0.32), radius: 1.5, y: 0.5)
                    .frame(width: 13.5, height: 13.5)
            }
            .frame(width: 31, height: 31)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHoverChange)
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

                    Button { [weak document] in
                        guard let document else { return }
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
