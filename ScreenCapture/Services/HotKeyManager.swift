import Carbon.HIToolbox
import Foundation

private final class HotKeyRegistrationStorage: @unchecked Sendable {
    var eventHandler: EventHandlerRef?
    var hotKeys: [UInt32: EventHotKeyRef] = [:]

    deinit {
        for reference in hotKeys.values { UnregisterEventHotKey(reference) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

@MainActor
final class HotKeyManager {
    static weak var active: HotKeyManager?

    private let registrations = HotKeyRegistrationStorage()
    private var actions: [UInt32: () -> Void] = [:]

    init() {
        HotKeyManager.active = self
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr else { return status }
                let hotKeyID = identifier.id
                Task { @MainActor in
                    HotKeyManager.active?.actions[hotKeyID]?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &registrations.eventHandler
        )
    }

    func unregisterAll() {
        for reference in registrations.hotKeys.values { UnregisterEventHotKey(reference) }
        registrations.hotKeys.removeAll()
        actions.removeAll()
    }

    func unregister(ids: ClosedRange<UInt32>) {
        for id in ids { unregister(id: id) }
    }

    func unregister(id: UInt32) {
        if let reference = registrations.hotKeys.removeValue(forKey: id) {
            UnregisterEventHotKey(reference)
        }
        actions.removeValue(forKey: id)
    }

    @discardableResult
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        unregister(id: id)
        let identifier = EventHotKeyID(signature: OSType(0x5343524E), id: id) // SCRN
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return false }
        registrations.hotKeys[id] = reference
        actions[id] = action
        return true
    }
}
