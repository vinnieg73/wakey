// Lid watching and the keyboard backlight, for "Lights Off When Lid Closes".
import AppKit
import IOKit

/// True when the MacBook lid is shut (IOPMrootDomain's AppleClamshellState).
func lidClosed() -> Bool {
    let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard root != 0 else { return false }
    defer { IOObjectRelease(root) }
    let v = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
    return (v?.takeRetainedValue() as? Bool) ?? false
}

/// Turns the displays off right away, without sleeping the Mac.
func displaysOffNow() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: pmset)
    p.arguments = ["displaysleepnow"]
    p.standardOutput = Pipe(); p.standardError = Pipe()
    try? p.run()
}

/// Keyboard backlight through Apple's private CoreBrightness framework.
/// Every call quietly does nothing if that API isn't there.
final class KeyboardLight {
    private var client: NSObject?
    private var id: UInt64 = 0

    init() {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return }
        let c = cls.init()
        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard c.responds(to: idsSel),
              let ids = c.perform(idsSel)?.takeRetainedValue() as? [NSNumber],
              let first = ids.first else { return }
        client = c
        id = first.uint64Value
    }

    /// Current level, 0...1.
    var level: Float? {
        let sel = NSSelectorFromString("brightnessForKeyboard:")
        guard let c = client, let m = class_getInstanceMethod(type(of: c), sel) else { return nil }
        typealias Get = @convention(c) (AnyObject, Selector, UInt64) -> Float
        return unsafeBitCast(method_getImplementation(m), to: Get.self)(c, sel, id)
    }

    func set(_ v: Float) {
        let sel = NSSelectorFromString("setBrightness:forKeyboard:")
        guard let c = client, let m = class_getInstanceMethod(type(of: c), sel) else { return }
        typealias Set = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        _ = unsafeBitCast(method_getImplementation(m), to: Set.self)(c, sel, v, id)
    }
}

/// Built-in screen brightness through Apple's private DisplayServices framework.
/// Every call quietly does nothing if that API isn't there or the built-in screen is off.
enum ScreenLight {
    private typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (UInt32, Float) -> Int32
    private static let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn = dlsym(lib, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: Get.self) }
    private static let setFn = dlsym(lib, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: Set.self) }

    private static var builtIn: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &n) == .success else { return nil }
        return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// Current level, 0...1.
    static var level: Float? {
        guard let get = getFn, let id = builtIn else { return nil }
        var v: Float = 0
        return get(id, &v) == 0 ? v : nil
    }

    static func set(_ v: Float) {
        guard let set = setFn, let id = builtIn else { return }
        _ = set(id, v)
    }
}
