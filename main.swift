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
func installRule() -> Bool {
    let rule = "\(NSUserName()) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0, \(pmset) -a disablesleep 1\n"
    let tmp = NSTemporaryDirectory() + "sleeptoggle.sudoers"
    guard (try? rule.write(toFile: tmp, atomically: true, encoding: .utf8)) != nil else { return false }
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    let sh = "/usr/sbin/visudo -cf '\(tmp)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp)' '\(sudoersFile)'"
    let script = "do shell script \"\(sh)\" with prompt \"Wakey needs your password one last time so it can switch sleep without asking again.\" with administrator privileges"
    var err: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&err)
    return err == nil
}

func setSleepDisabled(_ on: Bool) -> Bool {
    if sudoPmset(on) { return true }
    guard installRule() else { return false }
    return sudoPmset(on)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let stateRow = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let toggleRow = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    let loginRow = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    var awake = false

    func applicationDidFinishLaunching(_ n: Notification) {
        stateRow.isEnabled = false
        toggleRow.target = self
        loginRow.target = self
        menu.addItem(stateRow)
        menu.addItem(toggleRow)
        menu.addItem(.separator())
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

        refresh()
        // Pick up changes made elsewhere (for example in Terminal).
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
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
    }

    @objc func clicked() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            refresh()
            item.menu = menu
            item.button?.performClick(nil)
        } else {
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

    func menuDidClose(_ m: NSMenu) { item.menu = nil }

    @objc func toggle() {
        _ = setSleepDisabled(!awake)   // cancelling the password prompt just leaves it unchanged
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
