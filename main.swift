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

// One rule file per user. sudo skips files with a '.' in the name, so anything odd becomes '_'.
let sudoersFile: String = {
    let safe = String(String.UnicodeScalarView(NSUserName().unicodeScalars.map { c -> Unicode.Scalar in
        let ok = (c.value >= 48 && c.value <= 57) || (c.value >= 65 && c.value <= 90) || (c.value >= 97 && c.value <= 122) || c == "-" || c == "_"
        return ok ? c : "_"
    }))
    return "/etc/sudoers.d/sleeptoggle-" + safe
}()

let legacySudoersFile = "/etc/sudoers.d/sleeptoggle"   // older installs: one shared file

/// True when Wakey's rule file (or the legacy one) is in /etc/sudoers.d. Only checks that it exists.
func ruleFileExists() -> Bool {
    FileManager.default.fileExists(atPath: sudoersFile) || FileManager.default.fileExists(atPath: legacySudoersFile)
}

/// Runs pmset through sudo without a password. Returns whether it worked, and what went to stderr.
func sudoPmset(_ on: Bool) -> (ok: Bool, err: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    p.arguments = ["-n", pmset, "-a", "disablesleep", on ? "1" : "0"]
    let errPipe = Pipe()
    p.standardOutput = FileHandle.nullDevice; p.standardError = errPipe
    guard (try? p.run()) != nil else { return (false, "") }
    let err = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    p.waitUntilExit()
    return (p.terminationStatus == 0, err)
}

/// Wraps text in single quotes for /bin/sh.
func shQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

/// One-time setup (asks for the password once): lets this user run ONLY
/// `pmset -a disablesleep 0` and `pmset -a disablesleep 1` without a password.
func installRule() -> SwitchResult {
    let rule = "\(NSUserName()) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0, \(pmset) -a disablesleep 1"
    // The root shell writes the rule itself into a root-owned staging file (the '.' makes sudo ignore it),
    // checks that file, then moves it into place. No user-writable file is involved at any point.
    let staged = shQuote("/etc/sudoers.d/.\((sudoersFile as NSString).lastPathComponent).new")
    let sh = "/bin/rm -f \(staged) && (umask 0337 && printf '%s\\n' \(shQuote(rule)) > \(staged))"
        + " && /usr/sbin/chown root:wheel \(staged) && /bin/chmod 0440 \(staged)"
        + " && /usr/sbin/visudo -cf \(staged) && /bin/mv -f \(staged) \(shQuote(sudoersFile))"
        + " || { /bin/rm -f \(staged); exit 1; }"
    // AppleScript string: escape backslashes and double quotes.
    let asString = sh.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = "do shell script \"\(asString)\" with prompt \"Wakey needs your password one last time so it can switch sleep without asking again.\" with administrator privileges"
    var err: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&err)
    if err == nil { return .done }
    return (err?[NSAppleScript.errorNumber] as? Int) == -128 ? .cancelled : .failed   // -128: user cancelled
}

var askedForPassword = false   // set when the password box was shown

func setSleepDisabled(_ on: Bool) -> SwitchResult {
    askedForPassword = false
    let first = sudoPmset(on)
    if first.ok { return .done }
    // Our rule is there and sudo ran pmset, so pmset failed: asking for the password won't help.
    // (`sudo -n -l` can't tell this: any other NOPASSWD rule makes it pass. See Logic.swift.)
    if !failureNeedsRule(ruleFileExists: ruleFileExists(), sudoStderr: first.err) { return .pmsetFailed }
    askedForPassword = true
    let r = installRule()
    guard r == .done else { return r }
    let again = sudoPmset(on)
    return again.ok ? .done : resultAfterInstall(sudoStderr: again.err)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let stateRow = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let toggleRow = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    let loginRow = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    let lightsRow = NSMenuItem(title: "Lights Off When Lid Closes", action: #selector(toggleLights), keyEquivalent: "")
    let helpRow = NSMenuItem(title: "Wakey Help", action: #selector(showHelp), keyEquivalent: "")
    let quitRow = NSMenuItem(title: "Quit Wakey", action: #selector(quitFromMenu), keyEquivalent: "q")
    var activity: NSObjectProtocol?   // App Nap opt-out token
    var awake = false
    var busy = false                  // a switch is in progress
    var ignoreClicksUntil: TimeInterval = 0   // clicks queued before this time (system uptime) are dropped
    var lastClickEvent: (type: NSEvent.EventType, time: TimeInterval)?   // the event the button's last press saw

    let keyboard = KeyboardLight()
    var lidWasClosed = false
    var lightsAreOff = false {        // set while we have the keyboard light off; saved so a crash can't strand it
        didSet { UserDefaults.standard.set(lightsAreOff, forKey: "lightsOffByWakey") }
    }
    var recent: [(keyboard: Float?, screen: Float?)] = []   // last few readings while the lid is open
    var settling = 0                  // readings to skip right after the lid opens
    var lidTick = 0                   // counts lid checks, for the slower level reads in normal mode
    var lightsOffOnLid: Bool {
        get { UserDefaults.standard.bool(forKey: "lightsOffOnLid") }
        set { UserDefaults.standard.set(newValue, forKey: "lightsOffOnLid") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        stateRow.isEnabled = false
        toggleRow.target = self
        loginRow.target = self
        lightsRow.target = self
        helpRow.target = self
        quitRow.target = self
        menu.addItem(stateRow)
        menu.addItem(toggleRow)
        menu.addItem(.separator())
        menu.addItem(lightsRow)
        menu.addItem(loginRow)
        menu.addItem(.separator())
        menu.addItem(helpRow)
        menu.addItem(quitRow)
        menu.delegate = self

        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // VoiceOver and keyboard users: pressing the button switches, this action opens the menu.
        item.button?.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Show menu") { [weak self] in
                DispatchQueue.main.async { self?.showMenu() }   // after the accessibility call returns
                return true
            }
        ])

        // Start at login by default; after the first launch the menu checkmark decides.
        // Only from /Applications (not the build folder copy), and only marked done if it worked.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin"), Bundle.main.bundlePath.hasPrefix("/Applications/") {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "didSetupLogin")
            } catch {
                NSLog("Wakey: login item register failed: \(error.localizedDescription)")  // tries again next launch
            }
        }

        UserDefaults.standard.register(defaults: ["lightsOffOnLid": true])

        refresh()
        // Pick up changes made elsewhere (for example in Terminal). A click and opening the menu read the
        // real state anyway, so this only keeps the icon honest; every 15 s is enough.
        let t15 = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.refreshState() }
        t15.tolerance = 3
        RunLoop.main.add(t15, forMode: .common)   // .common: keeps running while the menu is open

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
        let t1 = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkLid() }
        t1.tolerance = 0.2
        RunLoop.main.add(t1, forMode: .common)
        // Stops App Nap from delaying the lid checks (the token must stay alive).
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Watching the lid")
    }

    // Opening the app again brings back a hidden menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        item.isVisible = true
        return true
    }

    func applicationWillTerminate(_ n: Notification) {
        // With the lid shut, leave the saved flag so the next launch restores the lights.
        if lightsAreOff, !lidClosed() { restoreLights() }
    }

    func checkLid() {
        let closed = lidClosed()
        lidTick += 1
        if closed, lightsAreOff, lightsOffOnLid, (keyboard.level ?? 0) > 0 { keyboard.set(0) }  // auto-brightness can relight it
        if !closed, settling > 0 || readLevelsNow(tick: lidTick, awake: awake) { remember() }   // every 5 s in normal mode; settling counts seconds
        guard closed != lidWasClosed else { return }
        lidWasClosed = closed
        if closed { recent.dropLast().forEach { save($0) } }  // keep older readings; the newest may be close-time dimming
        recent.removeAll()
        settling = 3
        if closed {
            lightsOff()
        } else if lightsAreOff {
            restoreLights()
        }
    }

    /// Lid is shut: keyboard light off, and the screen off unless an external display is attached.
    func lightsOff() {
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
    }

    /// Saves the keyboard and screen levels from 3 readings ago (3 s in awake mode, 15 s in normal mode),
    /// so dimming while the lid is closing (or just after it opens) never gets saved as the level to come back to.
    func remember() {
        if settling > 0 { settling -= 1; return }
        // A screen dimmed before display sleep (or asleep) must not become the level to come back to.
        let screenOK = screenReadingUsable(idleSeconds: userIdleSeconds(), displayAsleep: ScreenLight.isAsleep)
        recent.append((keyboard.level, screenOK ? ScreenLight.level : nil))
        guard recent.count > 3 else { return }
        save(recent.removeFirst())
    }

    /// Saves one reading. Keyboard 0 (idle-off), a screen reading of 0 (display off) and a missing
    /// reading (nil, also used for a screen dimmed or asleep) are skipped.
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

    /// Everything, including the login item status (an XPC call), for the menu and after changes.
    func refresh() {
        refreshState()
        let login = SMAppService.mainApp.status
        loginRow.title = login == .requiresApproval ? "Open at Login (needs approval)" : "Open at Login"
        loginRow.state = login == .enabled ? .on : login == .requiresApproval ? .mixed : .off
    }

    /// The sleep state, the icon and the menu titles. The timer runs only this part.
    func refreshState() {
        awake = sleepDisabled()
        let label = awake ? "Staying awake with lid closed" : "Normal sleep"
        let img = awake ? awakeIcon : sleepIcon
        img.isTemplate = false
        img.accessibilityDescription = label
        item.button?.image = img
        item.button?.toolTip = "\(label)\nClick to switch"
        stateRow.title = awake ? "Awake: lid can close" : "Normal sleep"
        toggleRow.title = awake ? "Allow Sleep Again" : "Keep Awake with Lid Closed"
        quitRow.title = quitTitle(awake: awake)
        lightsRow.state = lightsOffOnLid ? .on : .off
    }

    @objc func clicked() {
        // A VoiceOver press has no event of its own: currentEvent is whatever the app handled last
        // (an old click, the Return that closed an alert). Only a new mouse-up on the button is a click.
        let e = NSApp.currentEvent
        let seen = e.map { lastClickEvent?.type == $0.type && lastClickEvent?.time == $0.timestamp } ?? false
        if let e { lastClickEvent = (e.type, e.timestamp) }
        let action = clickAction(
            mouseUp: e?.type == .leftMouseUp || e?.type == .rightMouseUp,
            otherWindow: (e?.windowNumber ?? 0) != 0 && e?.windowNumber != item.button?.window?.windowNumber,   // the number outlives a freed alert
            seenBefore: seen,
            right: e?.type == .rightMouseUp,
            control: e?.modifierFlags.contains(.control) == true,
            time: e?.timestamp ?? 0,
            ignoreUntil: ignoreClicksUntil)   // clicks queued during the password box or the alert are dropped
        switch action {
        case .menu: showMenu()
        case .toggle: toggle()
        case .ignore: break
        }
    }

    func showMenu() {
        refresh()
        item.menu = menu
        item.button?.performClick(nil)
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                UserDefaults.standard.set(true, forKey: "didSetupLogin")   // the user chose; launch won't override it
            } else if service.status == .requiresApproval {
                // Handled below: opens System Settings.
            } else if !Bundle.main.bundlePath.hasPrefix("/Applications/") {
                // A build-folder copy would register a path the next build deletes.
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Open at Login works only from Applications"
                alert.informativeText = "Copy Wakey to /Applications and open it from there, then turn this on."
                alert.runModal()
            } else {
                try service.register()
                UserDefaults.standard.set(true, forKey: "didSetupLogin")
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        // Needs the user's OK in System Settings.
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        refresh()
    }

    @objc func toggleLights() {
        lightsOffOnLid.toggle()
        // Ticked with the lid already shut: act now. Unticked: checkLid stops holding the light at 0,
        // and it comes back as usual when the lid opens.
        if lightsOffOnLid, lidWasClosed { lightsOff() }
        refresh()
    }

    func menuDidClose(_ m: NSMenu) { item.menu = nil }

    @objc func showHelp() {
        guard !busy else { return }
        busy = true
        defer { busy = false }   // as with the other alerts: no switching while it's open
        NSApp.activate(ignoringOtherApps: true)
        makeHelpAlert().runModal()
        ignoreClicksUntil = ProcessInfo.processInfo.systemUptime
    }

    /// The menu's Quit. While awake mode is on it switches back to normal sleep first: quitting would
    /// otherwise leave the Mac unable to sleep, with no icon left to switch it back. A restart, a logout
    /// and `quit app "Wakey"` (the install steps) don't come through here, so they keep the setting.
    @objc func quitFromMenu() {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if sleepDisabled() {
            let result = setSleepDisabled(false)
            if quitNeedsWarning(result) {
                NSApp.activate(ignoringOtherApps: true)
                let a = NSAlert()
                a.messageText = "Wakey couldn't switch sleep back on"
                a.informativeText = "If you quit now, the Mac stays awake with the lid closed, and there's no icon to switch it back."
                a.addButton(withTitle: "Don't Quit")
                a.addButton(withTitle: "Quit Anyway")
                let stay = a.runModal() == .alertFirstButtonReturn
                ignoreClicksUntil = ProcessInfo.processInfo.systemUptime
                if stay { refresh(); return }
            }
        }
        NSApp.terminate(nil)
    }

    @objc func toggle() {
        guard !busy else { return }
        busy = true
        defer { busy = false }   // stays set while the alert is open, so clicks during it can't start another switch
        let on = !sleepDisabled()   // read the real state, not the cached one
        let result = setSleepDisabled(on)
        if askedForPassword { ignoreClicksUntil = ProcessInfo.processInfo.systemUptime }
        if result == .failed || result == .pmsetFailed || result == .ruleOverridden {   // cancelling the password prompt stays silent and leaves it unchanged
            NSApp.activate(ignoringOtherApps: true)
            let a = NSAlert()
            a.messageText = "Wakey couldn't switch sleep"
            switch result {
            case .pmsetFailed:
                a.informativeText = "The permission is set up, but pmset itself failed. Try again, or run \"pmset -g\" in Terminal to check."
            case .ruleOverridden:
                a.informativeText = "Wakey's permission is installed, but another sudo rule on this Mac overrides it. Check the other files in /etc/sudoers.d."
            default:
                a.informativeText = "Switching needs an administrator account, and its password once, the first time."
            }
            a.runModal()
            ignoreClicksUntil = ProcessInfo.processInfo.systemUptime
        }
        if lightsOffAfterSwitch(result: result, nowAwake: on, lidShut: lidClosed()) { lightsOff() }
        refresh()
    }
}

// Only one Wakey at a time (e.g. build folder copy and /Applications copy).
if let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != NSRunningApplication.current }) {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
