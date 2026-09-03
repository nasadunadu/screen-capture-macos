import AppKit
import Carbon.HIToolbox
import Foundation

struct ShortcutKeyOption: Codable, Hashable, Identifiable {
    let label: String
    let keyCode: UInt32

    var id: UInt32 { keyCode }

    static let supported: [ShortcutKeyOption] = [
        .init(label: "0", keyCode: UInt32(kVK_ANSI_0)),
        .init(label: "1", keyCode: UInt32(kVK_ANSI_1)),
        .init(label: "2", keyCode: UInt32(kVK_ANSI_2)),
        .init(label: "3", keyCode: UInt32(kVK_ANSI_3)),
        .init(label: "4", keyCode: UInt32(kVK_ANSI_4)),
        .init(label: "5", keyCode: UInt32(kVK_ANSI_5)),
        .init(label: "6", keyCode: UInt32(kVK_ANSI_6)),
        .init(label: "7", keyCode: UInt32(kVK_ANSI_7)),
        .init(label: "8", keyCode: UInt32(kVK_ANSI_8)),
        .init(label: "9", keyCode: UInt32(kVK_ANSI_9)),
        .init(label: "A", keyCode: UInt32(kVK_ANSI_A)),
        .init(label: "C", keyCode: UInt32(kVK_ANSI_C)),
        .init(label: "L", keyCode: UInt32(kVK_ANSI_L)),
        .init(label: "S", keyCode: UInt32(kVK_ANSI_S)),
        .init(label: "W", keyCode: UInt32(kVK_ANSI_W))
    ]

    static func from(event: NSEvent) -> ShortcutKeyOption? {
        let specialKeys: [UInt16: String] = [
            UInt16(kVK_Space): "Space",
            UInt16(kVK_LeftArrow): "←",
            UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑",
            UInt16(kVK_DownArrow): "↓"
        ]
        if let label = specialKeys[event.keyCode] {
            return ShortcutKeyOption(label: label, keyCode: UInt32(event.keyCode))
        }
        guard let characters = event.charactersIgnoringModifiers?.uppercased(),
              let first = characters.first,
              first.isLetter || first.isNumber else { return nil }
        return ShortcutKeyOption(label: String(first), keyCode: UInt32(event.keyCode))
    }
}

struct ShortcutModifierOption: Hashable, Identifiable {
    let label: String
    let carbonFlags: UInt32

    var id: UInt32 { carbonFlags }

    static let supported: [ShortcutModifierOption] = [
        .init(label: "⌘", carbonFlags: UInt32(cmdKey)),
        .init(label: "⇧⌘", carbonFlags: UInt32(shiftKey | cmdKey)),
        .init(label: "⌃⌘", carbonFlags: UInt32(controlKey | cmdKey)),
        .init(label: "⌥⌘", carbonFlags: UInt32(optionKey | cmdKey)),
        .init(label: "⌃⇧", carbonFlags: UInt32(controlKey | shiftKey))
    ]
}

struct KeyboardShortcutDefinition: Codable, Hashable {
    var key: ShortcutKeyOption
    var modifiers: UInt32

    var displayName: String {
        var prefix = ""
        if modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        return prefix + key.label
    }

    init(key: ShortcutKeyOption, modifiers: UInt32) {
        self.key = key
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        guard let key = ShortcutKeyOption.from(event: event) else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        guard carbonFlags != 0 else { return nil }
        self.init(key: key, modifiers: carbonFlags)
    }

    static let normalDefault = KeyboardShortcutDefinition(
        key: ShortcutKeyOption(label: "4", keyCode: UInt32(kVK_ANSI_4)),
        modifiers: UInt32(cmdKey)
    )

    static let longCaptureDefault = KeyboardShortcutDefinition(
        key: ShortcutKeyOption(label: "5", keyCode: UInt32(kVK_ANSI_5)),
        modifiers: UInt32(cmdKey)
    )
}
