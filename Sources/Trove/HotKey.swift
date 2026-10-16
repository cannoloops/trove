import AppKit
import Carbon.HIToolbox

/// Scorciatoia globale via Carbon RegisterEventHotKey (nessuna dipendenza, niente permessi extra).
@MainActor
final class HotKey {
    struct Combo: Equatable {
        var keyCode: UInt32
        var modifiers: UInt32 // Carbon: cmdKey, shiftKey, optionKey, controlKey

        static let `default` = Combo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))

        static func load() -> Combo {
            let d = UserDefaults.standard
            guard d.object(forKey: "hotKeyCode") != nil else { return .default }
            return Combo(keyCode: UInt32(d.integer(forKey: "hotKeyCode")), modifiers: UInt32(d.integer(forKey: "hotKeyMods")))
        }

        func save() {
            UserDefaults.standard.set(Int(keyCode), forKey: "hotKeyCode")
            UserDefaults.standard.set(Int(modifiers), forKey: "hotKeyMods")
        }

        init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }

        init?(event: NSEvent) {
            let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var m: UInt32 = 0
            if f.contains(.command) { m |= UInt32(cmdKey) }
            if f.contains(.shift) { m |= UInt32(shiftKey) }
            if f.contains(.option) { m |= UInt32(optionKey) }
            if f.contains(.control) { m |= UInt32(controlKey) }
            guard m & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil } // serve almeno ⌘, ⌥ o ⌃
            self.init(keyCode: UInt32(event.keyCode), modifiers: m)
        }

        var display: String {
            var s = ""
            if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
            if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
            if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
            if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
            return s + Self.keyName(keyCode)
        }

        static func keyName(_ code: UInt32) -> String {
            let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
                                          kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6"]
            if let s = special[Int(code)] { return s }
            guard let src = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return "#\(code)" }
            let layout = unsafeBitCast(ptr, to: CFData.self)
            var dead: UInt32 = 0, len = 0
            var chars = [UniChar](repeating: 0, count: 4)
            UCKeyTranslate(unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self), UInt16(code),
                           UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                           &dead, 4, &len, &chars)
            return String(utf16CodeUnits: chars, count: len).uppercased()
        }
    }

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            let me = Unmanaged<HotKey>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { me.action() } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ combo: Combo) -> Bool {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        let id = EventHotKeyID(signature: OSType(0x54524F56), id: 1) // 'TROV'
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        NSLog("Trove hotkey %@ register status %d", combo.display, status)
        return status == noErr
    }
}
