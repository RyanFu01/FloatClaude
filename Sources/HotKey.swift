import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Uses Carbon's RegisterEventHotKey, which still works on modern macOS and,
/// unlike an NSEvent global monitor, needs no Accessibility permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Returns nil if the shortcut couldn't be registered.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let me = Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x464C_434C), id: 1) // 'FLCL'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            NSLog("FloatClaude: hotkey registration failed (\(status))")
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
