// Wakey: a menu bar switch that keeps the Mac awake with the lid closed.
// Click the icon to flip it. Right-click (or Control-click) for the menu.
import AppKit
import ServiceManagement

let pmset = "/usr/bin/pmset"

/// True when lid-closed sleep is currently disabled.
func sleepDisabled() -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: pmset)
    p.arguments = ["-g"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    guard (try? p.run()) != nil else { return false }
    let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    p.waitUntilExit()
    for line in out.split(separator: "\n") {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        if parts.first == "SleepDisabled" { return parts.last == "1" }
    }
    return false
}

let sudoersFile = "/etc/sudoers.d/sleeptoggle"

func sudoPmset(_ on: Bool) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    p.arguments = ["-n", pmset, "-a", "disablesleep", on ? "1" : "0"]
    p.standardOutput = Pipe(); p.standardError = Pipe()
    guard (try? p.run()) != nil else { return false }
    p.waitUntilExit()
    return p.terminationStatus == 0
}

/// One-time setup (asks for the password once): lets this user run ONLY
/// `pmset -a disablesleep 0` and `pmset -a disablesleep 1` without a password.
func installRule() -> SwitchResult {
    let rule = "\(NSUserName()) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0, \(pmset) -a disablesleep 1\n"
    let tmp = NSTemporaryDirectory() + "sleeptoggle.sudoers-" + UUID().uuidString
    guard (try? rule.write(toFile: tmp, atomically: true, encoding: .utf8)) != nil else { return .failed }
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    let sh = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' '\(sudoersFile)'"
    let script = "do shell script \"\(sh)\" with prompt \"Wakey needs your password one last time so it can switch sleep without asking again.\" with administrator privileges"
    var err: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&err)
    if err == nil { return .done }
    return (err?[NSAppleScript.errorNumber] as? Int) == -128 ? .cancelled : .failed   // -128: user cancelled
}

enum SwitchResult { case done, cancelled, failed }

var askedForPassword = false   // set when the password box was shown

func setSleepDisabled(_ on: Bool) -> SwitchResult {
    askedForPassword = false
    if sudoPmset(on) { return .done }
    askedForPassword = true
    let r = installRule()
    guard r == .done else { return r }
    return sudoPmset(on) ? .done : .failed
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let stateRow = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let toggleRow = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    let loginRow = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    let lightsRow = NSMenuItem(title: "Lights Off When Lid Closes", action: #selector(toggleLights), keyEquivalent: "")
    var awake = false
    var busy = false                  // a switch is in progress
    var ignoreClicksUntil: TimeInterval = 0   // clicks queued before this time (system uptime) are dropped

    let keyboard = KeyboardLight()
    var lidWasClosed = false
    var lightsAreOff = false {        // set while we have the keyboard light off; saved so a crash can't strand it
        didSet { UserDefaults.standard.set(lightsAreOff, forKey: "lightsOffByWakey") }
    }
    var recent: [(keyboard: Float?, screen: Float?)] = []   // last few readings while the lid is open
    var settling = 0                  // readings to skip right after the lid opens
    var lightsOffOnLid: Bool {
        get { UserDefaults.standard.bool(forKey: "lightsOffOnLid") }
        set { UserDefaults.standard.set(newValue, forKey: "lightsOffOnLid") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        stateRow.isEnabled = false
        toggleRow.target = self
        loginRow.target = self
        lightsRow.target = self
        menu.addItem(stateRow)
        menu.addItem(toggleRow)
        menu.addItem(.separator())
        menu.addItem(lightsRow)
        menu.addItem(loginRow)
        menu.addItem(NSMenuItem(title: "Quit Wakey", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self

        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Start at login by default; after the first launch the menu checkmark decides.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "didSetupLogin")
        }

        UserDefaults.standard.register(defaults: ["lightsOffOnLid": true])

        refresh()
        // Pick up changes made elsewhere (for example in Terminal).
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }

        // Watch the lid. Starting with the lid already shut doesn't count as closing it.
        lidWasClosed = lidClosed()
        let d = UserDefaults.standard
        if d.bool(forKey: "lightsOffByWakey") {
            // Wakey died with the lights off: bring them back now, or keep them off until the lid opens.
            if lidWasClosed { lightsAreOff = true } else { restoreLights() }
        } else if !lidWasClosed, d.object(forKey: "lastKeyboardLevel") == nil || d.object(forKey: "lastScreenLevel") == nil {
            // Nothing saved yet (first launch): save what we see now.
            save((keyboard.level, ScreenLight.level))
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkLid() }
    }

    func applicationWillTerminate(_ n: Notification) {
        // With the lid shut, leave the saved flag so the next launch restores the lights.
        if lightsAreOff, !lidClosed() { restoreLights() }
    }

    func checkLid() {
        let closed = lidClosed()
        if closed, lightsAreOff, (keyboard.level ?? 0) > 0 { keyboard.set(0) }  // auto-brightness can relight it
        if !closed { remember() }
        guard closed != lidWasClosed else { return }
        lidWasClosed = closed
        if closed { recent.dropLast().forEach { save($0) } }  // keep older readings; the newest may be close-time dimming
        recent.removeAll()
        settling = 3
        if closed {
            // Only while staying awake: in normal mode the Mac just goes to sleep.
            guard lightsOffOnLid, !lightsAreOff, sleepDisabled() else { return }
            lightsAreOff = true
            keyboard.set(0)
            // With an external display attached, the lid closing is just clamshell mode: leave screens on.
            let external = NSScreen.screens.contains {
                guard let n = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(n.uint32Value) == 0
            }
            if !external { displaysOffNow() }
        } else if lightsAreOff {
            restoreLights()
        }
    }

    /// Saves the keyboard and screen levels from 3 seconds ago, so dimming while the lid
    /// is closing (or just after it opens) never gets saved as the level to come back to.
    func remember() {
        if settling > 0 { settling -= 1; return }
        recent.append((keyboard.level, ScreenLight.level))
        guard recent.count > 3 else { return }
        save(recent.removeFirst())
    }

    /// Saves one reading. Keyboard 0 (idle-off) and a screen reading of 0 (display off) are skipped.
    func save(_ r: (keyboard: Float?, screen: Float?)) {
        if let k = r.keyboard, k > 0.02 { UserDefaults.standard.set(k, forKey: "lastKeyboardLevel") }
        if let s = r.screen, s > 0.001 { UserDefaults.standard.set(s, forKey: "lastScreenLevel") }
    }

    /// Puts the keyboard and screen back to their last lid-open levels. Applied a few times,
    /// since macOS sets its own levels for a moment after the lid opens.
    func restoreLights() {
        lightsAreOff = false
        let d = UserDefaults.standard
        let k = d.object(forKey: "lastKeyboardLevel") == nil ? nil : d.float(forKey: "lastKeyboardLevel")
        let s = d.object(forKey: "lastScreenLevel") == nil ? nil : d.float(forKey: "lastScreenLevel")
        let apply = { [weak self] in
            if let k { self?.keyboard.set(k) }
            if let s { ScreenLight.set(s) }
        }
        apply()
        for delay in [0.3, 1, 2.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if self?.lidWasClosed == false { apply() }
            }
        }
    }

    func refresh() {
        awake = sleepDisabled()
        let label = awake ? "Staying awake with lid closed" : "Normal sleep"
        let img = awake ? awakeIcon : sleepIcon
        img.isTemplate = false
        img.accessibilityDescription = label
        item.button?.image = img
        item.button?.toolTip = "\(label)\nClick to switch"
        stateRow.title = awake ? "Awake: lid can close" : "Normal sleep"
        toggleRow.title = awake ? "Allow Sleep Again" : "Keep Awake with Lid Closed"
        loginRow.state = SMAppService.mainApp.status == .enabled ? .on : .off
        lightsRow.state = lightsOffOnLid ? .on : .off
    }

    @objc func clicked() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            refresh()
            item.menu = menu
            item.button?.performClick(nil)
        } else {
            if let t = e?.timestamp, t < ignoreClicksUntil { return }   // queued during the password box
            toggle()
        }
    }

    @objc func toggleLogin() {
        if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
        refresh()
    }

    @objc func toggleLights() {
        lightsOffOnLid.toggle()
        refresh()
    }

    func menuDidClose(_ m: NSMenu) { item.menu = nil }

    @objc func toggle() {
        guard !busy else { return }
        busy = true
        let result = setSleepDisabled(!sleepDisabled())   // read the real state, not the cached one
        if askedForPassword { ignoreClicksUntil = ProcessInfo.processInfo.systemUptime }
        busy = false
        if result == .failed {   // cancelling the password prompt stays silent and leaves it unchanged
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = "Wakey couldn't switch sleep"
            a.informativeText = "Switching needs an administrator account, and its password once, the first time."
            a.runModal()
            ignoreClicksUntil = ProcessInfo.processInfo.systemUptime
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
