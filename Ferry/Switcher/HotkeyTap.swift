import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Listens to keyboard events only (key down, key up, modifier changes) and
/// lets the switcher swallow the ones it handles. No mouse events, no polling:
/// between keystrokes this costs nothing.
@MainActor
final class HotkeyTap {
    struct Key {
        let code: Int64
        let flags: CGEventFlags

        /// What the key types on the current keyboard layout without ⌥, ⌃ or ⌘
        /// (Shift kept), so holding ⌥ gives "w" rather than "∑". The event's own
        /// string was made with ⌥ applied, so it's translated again here.
        /// Computed on demand: most keystrokes never need it.
        var characters: String {
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else { return "" }
            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
            let modifiers: UInt32 = flags.contains(.maskShift) ? UInt32(shiftKey >> 8) : 0
            var deadKeys: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 4)
            let status = data.withUnsafeBytes { bytes -> OSStatus in
                guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return -1 }
                return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                                      OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &buffer)
            }
            return status == noErr ? String(utf16CodeUnits: buffer, count: length) : ""
        }
    }

    enum Kind { case down, up, modifiers }

    /// Return true to swallow the event.
    var handler: ((Kind, Key) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                          callback: tapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            log.error("Couldn't create the keyboard event tap")
            return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns a slow tap off; turn it straight back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .keyDown, .keyUp, .flagsChanged:
            let kind: Kind = type == .keyDown ? .down : type == .keyUp ? .up : .modifiers
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            return handler?(kind, Key(code: code, flags: event.flags)) ?? false
        default:
            return false
        }
    }
}

private func tapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                         _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<HotkeyTap>.fromOpaque(userInfo).takeUnretainedValue()
    let swallow = MainActor.assumeIsolated { tap.handle(type, event) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}

/// Virtual key codes Ferry cares about (US layout positions; letters are matched by character).
enum KeyCode {
    static let tab: Int64 = 48
    static let space: Int64 = 49
    static let delete: Int64 = 51
    static let escape: Int64 = 53
    static let returnKey: Int64 = 36
    static let enter: Int64 = 76
    static let left: Int64 = 123
    static let right: Int64 = 124
    static let down: Int64 = 125
    static let up: Int64 = 126
}
