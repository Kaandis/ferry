import AppKit
import ApplicationServices

/// The private macOS interfaces Ferry relies on, looked up at runtime so a
/// future macOS that drops one disables that piece instead of crashing.
///
/// - `_AXUIElementGetWindow` maps an Accessibility window to its WindowServer id.
/// - `_AXUIElementCreateWithRemoteToken` reaches windows on other Spaces, which
///   an app's `AXWindows` list leaves out.
/// - SkyLight's Space and front-process calls let a window come forward on its
///   own Space, the way clicking it in Mission Control does.
enum PrivateAPI {
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias RemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias SpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias ManagedSpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias SetFrontFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> Int32
    private typealias PostEventFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias ProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SymbolicHotKeyFn = @convention(c) (Int32, Bool) -> Int32

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_LAZY)
    private static let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?, as: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static let getWindow = symbol("_AXUIElementGetWindow", in: defaultHandle, as: GetWindowFn.self)
    private static let remoteToken = symbol("_AXUIElementCreateWithRemoteToken", in: defaultHandle, as: RemoteTokenFn.self)
    private static let processForPID = symbol("GetProcessForPID", in: defaultHandle, as: ProcessForPIDFn.self)
    private static let mainConnection = symbol("SLSMainConnectionID", in: skyLight, as: ConnectionFn.self)
    private static let spacesForWindows = symbol("SLSCopySpacesForWindows", in: skyLight, as: SpacesForWindowsFn.self)
    private static let managedSpaces = symbol("SLSCopyManagedDisplaySpaces", in: skyLight, as: ManagedSpacesFn.self)
    private static let setFront = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight, as: SetFrontFn.self)
    private static let postEvent = symbol("SLPSPostEventRecordTo", in: skyLight, as: PostEventFn.self)
    private static let symbolicHotKey = symbol("SLSSetSymbolicHotKeyEnabled", in: skyLight, as: SymbolicHotKeyFn.self)
        ?? symbol("CGSSetSymbolicHotKeyEnabled", in: defaultHandle, as: SymbolicHotKeyFn.self)

    private static let connection: Int32 = mainConnection?() ?? 0

    // MARK: Windows

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var id: CGWindowID = 0
        return getWindow(element, &id) == .success && id != 0 ? id : nil
    }

    /// Accessibility elements are addressed by a token of pid, a fixed tag and
    /// a per-process counter. Walking the counter finds windows that live on
    /// other Spaces. Slow-ish (one IPC per id), so callers cache the result.
    static func windowsByToken(pid: pid_t, limit: UInt64 = 1000) -> [AXUIElement] {
        guard let remoteToken else { return [] }
        var token = Data(count: 20)
        token.withUnsafeMutableBytes { raw in
            raw.storeBytes(of: pid, toByteOffset: 0, as: pid_t.self)
            raw.storeBytes(of: Int32(0), toByteOffset: 4, as: Int32.self)
            raw.storeBytes(of: Int32(0x636f_636f), toByteOffset: 8, as: Int32.self) // "coco"
        }
        var found: [AXUIElement] = []
        for id in 0..<limit {
            token.withUnsafeMutableBytes { $0.storeBytes(of: id, toByteOffset: 12, as: UInt64.self) }
            guard let element = remoteToken(token as CFData)?.takeRetainedValue() else { continue }
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
               role as? String == kAXWindowRole {
                found.append(element)
            }
        }
        return found
    }

    // MARK: Spaces

    struct SpaceInfo {
        /// Space ids currently shown, one per display.
        var visible: Set<UInt64> = []
        /// Ordinary desktop Spaces in Mission Control order, numbered from 1.
        var numbers: [UInt64: Int] = [:]
        /// Spaces that hold a single full-screen app.
        var fullScreen: Set<UInt64> = []
    }

    static func spaceInfo() -> SpaceInfo {
        var info = SpaceInfo()
        guard let managedSpaces,
              let displays = managedSpaces(connection)?.takeRetainedValue() as? [[String: Any]] else { return info }
        var number = 0
        for display in displays {
            if let current = display["Current Space"] as? [String: Any], let id = current["id64"] as? UInt64 {
                info.visible.insert(id)
            }
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                guard let id = space["id64"] as? UInt64 else { continue }
                if space["type"] as? Int == 4 {
                    info.fullScreen.insert(id)
                } else {
                    number += 1
                    info.numbers[id] = number
                }
            }
        }
        return info
    }

    static func spaces(for windowID: CGWindowID) -> [UInt64] {
        guard let spacesForWindows,
              let result = spacesForWindows(connection, 0x7, [windowID] as CFArray)?.takeRetainedValue() as? [NSNumber]
        else { return [] }
        return result.map(\.uint64Value)
    }

    // MARK: Focus

    /// Brings `windowID` forward as the key window of its app, switching Space
    /// if needed. Returns false if the private path isn't available.
    @discardableResult
    static func makeKeyAndFront(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let processForPID, let setFront, let postEvent else { return false }
        var psn = ProcessSerialNumber()
        guard processForPID(pid, &psn) == noErr else { return false }
        _ = setFront(&psn, windowID, 0x200) // user generated

        // Two synthetic "make key window" event records, as a click would send.
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { id in
            for (offset, byte) in id.enumerated() { bytes[0x3c + offset] = byte }
        }
        for offset in 0x20..<0x30 { bytes[offset] = 0xff }
        bytes[0x08] = 0x01
        _ = postEvent(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = postEvent(&psn, &bytes)
        return true
    }

    // MARK: ⌘Tab

    /// Turns the system's own ⌘Tab and ⇧⌘Tab on or off. WindowServer keeps
    /// this per login session, so Ferry restores it on quit.
    static func setSystemCommandTab(enabled: Bool) {
        guard let symbolicHotKey else { return }
        _ = symbolicHotKey(1, enabled)
        _ = symbolicHotKey(2, enabled)
    }
}
