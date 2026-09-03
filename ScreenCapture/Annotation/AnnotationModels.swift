import AppKit
import Foundation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case rectangle
    case ellipse
    case line
    case arrow
    case pen
    case text
    case spotlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "选择"
        case .rectangle: "矩形"
        case .ellipse: "椭圆"
        case .line: "直线"
        case .arrow: "箭头"
        case .pen: "画笔"
        case .text: "文字"
        case .spotlight: "聚光"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .pen: "pencil"
        case .text: "textformat"
        case .spotlight: "square.inset.filled"
        }
    }

    var supportsColor: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .pen, .text:
            true
        case .select, .spotlight:
            false
        }
    }

    var supportsLineWidth: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .arrow, .pen, .text:
            true
        case .select, .spotlight:
            false
        }
    }
}

struct AnnotationStyle {
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 5
    var opacity: CGFloat = 1
    var filled = false
    var spotlightEllipse = true
}

struct AnnotationArrowGeometry {
    let points: [CGPoint]

    var bounds: CGRect {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: max(1, (xs.max() ?? 0) - (xs.min() ?? 0)),
            height: max(1, (ys.max() ?? 0) - (ys.min() ?? 0))
        )
    }

    static func make(start: CGPoint, end: CGPoint, lineWidth: CGFloat) -> AnnotationArrowGeometry? {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let length = hypot(deltaX, deltaY)
        guard length > 0.5, length.isFinite else { return nil }

        let width = min(18, max(1, lineWidth.isFinite ? lineWidth : 5))
        let unit = CGPoint(x: deltaX / length, y: deltaY / length)
        let perpendicular = CGPoint(x: -unit.y, y: unit.x)
        let relativeHeadLength = min(54, length * 0.15)
        let desiredHeadLength = max(18, max(relativeHeadLength, width * 5))
        let headLength = min(length * 0.42, desiredHeadLength)
        let headHalfWidth = min(length * 0.24, max(headLength * 0.5, width * 2.4))
        let shaftHalfWidth = min(headHalfWidth * 0.38, max(0.75, width * 0.9))
        let headBase = CGPoint(
            x: end.x - unit.x * headLength,
            y: end.y - unit.y * headLength
        )

        func offset(_ point: CGPoint, by amount: CGFloat) -> CGPoint {
            CGPoint(
                x: point.x + perpendicular.x * amount,
                y: point.y + perpendicular.y * amount
            )
        }

        return AnnotationArrowGeometry(points: [
            start,
            offset(headBase, by: shaftHalfWidth),
            offset(headBase, by: headHalfWidth),
            end,
            offset(headBase, by: -headHalfWidth),
            offset(headBase, by: -shaftHalfWidth)
        ])
    }
}

struct AnnotationElement: Identifiable {
    let id: UUID
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint]
    var text: String
    var style: AnnotationStyle

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        start: CGPoint,
        end: CGPoint,
        points: [CGPoint] = [],
        text: String = "",
        style: AnnotationStyle
    ) {
        self.id = id
        self.tool = tool
        self.start = start
        self.end = end
        self.points = points
        self.text = text
        self.style = style
    }

    var bounds: CGRect {
        if tool == .arrow,
           let geometry = AnnotationArrowGeometry.make(start: start, end: end, lineWidth: style.lineWidth) {
            return geometry.bounds
        }
        if !points.isEmpty {
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            return CGRect(
                x: xs.min() ?? start.x,
                y: ys.min() ?? start.y,
                width: max(1, (xs.max() ?? end.x) - (xs.min() ?? start.x)),
                height: max(1, (ys.max() ?? end.y) - (ys.min() ?? start.y))
            )
        }
        if tool == .text {
            return CGRect(x: start.x, y: start.y - 4, width: max(80, CGFloat(text.count) * 18), height: 30)
        }
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(1, abs(end.x - start.x)),
            height: max(1, abs(end.y - start.y))
        )
    }

    mutating func translate(by delta: CGSize) {
        start.x += delta.width
        start.y += delta.height
        end.x += delta.width
        end.y += delta.height
        points = points.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
    }
}

@MainActor
final class AnnotationDocument: ObservableObject {
    @Published var tool: AnnotationTool = .arrow
    @Published var style = AnnotationStyle()
    @Published private(set) var elements: [AnnotationElement] = []
    @Published var selectedElementID: UUID?

    private var undoStack: [[AnnotationElement]] = []
    private var redoStack: [[AnnotationElement]] = []
    private var isAdjustingLineWidth = false
    private var lineWidthAdjustmentHasSnapshot = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var activeColor: NSColor {
        guard let selectedElementID,
              let selected = element(id: selectedElementID),
              selected.tool.supportsColor else { return style.color }
        return selected.style.color
    }
    var activeLineWidth: CGFloat {
        guard let selectedElementID,
              let selected = element(id: selectedElementID),
              selected.tool.supportsLineWidth else { return style.lineWidth }
        return selected.style.lineWidth
    }

    func beginMutation() {
        undoStack.append(elements)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func append(_ element: AnnotationElement) {
        elements.append(element)
        selectedElementID = element.id
        objectWillChange.send()
    }

    func update(_ element: AnnotationElement) {
        guard let index = elements.firstIndex(where: { $0.id == element.id }) else { return }
        elements[index] = element
        objectWillChange.send()
    }

    func setColor(_ color: NSColor) {
        style.color = color
        guard let selectedElementID,
              let index = elements.firstIndex(where: { $0.id == selectedElementID }),
              elements[index].tool.supportsColor,
              !elements[index].style.color.isEqual(color) else { return }
        beginMutation()
        elements[index].style.color = color
        objectWillChange.send()
    }

    func beginLineWidthAdjustment() {
        isAdjustingLineWidth = true
        lineWidthAdjustmentHasSnapshot = false
    }

    func setLineWidth(_ width: CGFloat) {
        let normalizedWidth = min(18, max(1, width.isFinite ? width : 5))
        style.lineWidth = normalizedWidth
        guard let selectedElementID,
              let index = elements.firstIndex(where: { $0.id == selectedElementID }),
              elements[index].tool.supportsLineWidth,
              elements[index].style.lineWidth != normalizedWidth else { return }

        if !isAdjustingLineWidth || !lineWidthAdjustmentHasSnapshot {
            beginMutation()
            lineWidthAdjustmentHasSnapshot = true
        }
        elements[index].style.lineWidth = normalizedWidth
        objectWillChange.send()
    }

    func endLineWidthAdjustment() {
        isAdjustingLineWidth = false
        lineWidthAdjustmentHasSnapshot = false
    }

    func element(id: UUID) -> AnnotationElement? {
        elements.first(where: { $0.id == id })
    }

    func removeSelected() {
        guard let selectedElementID,
              elements.contains(where: { $0.id == selectedElementID }) else { return }
        beginMutation()
        elements.removeAll(where: { $0.id == selectedElementID })
        self.selectedElementID = nil
        objectWillChange.send()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = previous
        selectedElementID = nil
        objectWillChange.send()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = next
        selectedElementID = nil
        objectWillChange.send()
    }
}
