// Checks for Logic.swift. Run with tests/run.sh. Exits 1 if any check fails.
import Foundation

@main
enum LogicTests {
    static var failures = 0
    static var passes = 0

    static func check(_ ok: Bool, _ name: String) {
        if ok { passes += 1 } else { failures += 1; print("FAIL: \(name)") }
    }

    static func main() {
        sudoCheck()
        clicks()
        switchWithLidShut()
        polling()
        print("\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    // Audit 2026-10-23 Medium: "is the rule already working?" must not be fooled by other sudo rules.
    static func sudoCheck() {
        let needsPassword = "sudo: a password is required\n"
        let notAllowed = "Sorry, user vinnie is not allowed to execute '/usr/bin/pmset -a disablesleep 1' as root on mac.\n"
        // No Wakey rule file, but another NOPASSWD rule let sudo run pmset, and pmset failed:
        // the old `sudo -n -l` check said "pmset itself failed" here. It must ask for the password.
        check(failureNeedsRule(ruleFileExists: false, sudoStderr: ""), "no rule file, silent failure -> install")
        check(failureNeedsRule(ruleFileExists: false, sudoStderr: needsPassword), "no rule file, password -> install")
        // Rule file there, but a later sudoers file overrides it: sudo still wants a password.
        check(failureNeedsRule(ruleFileExists: true, sudoStderr: needsPassword), "rule file, password -> install")
        check(failureNeedsRule(ruleFileExists: true, sudoStderr: notAllowed), "rule file, not allowed -> install")
        check(failureNeedsRule(ruleFileExists: true, sudoStderr: "sudo: unable to read /etc/sudoers.d/x\n"), "rule file, other sudo error -> install")
        // Rule file there and sudo ran pmset: the failure is pmset's own.
        check(!failureNeedsRule(ruleFileExists: true, sudoStderr: ""), "rule file, silent pmset failure -> pmset failed")
        check(!failureNeedsRule(ruleFileExists: true, sudoStderr: "pmset: Usage error\n"), "rule file, pmset error -> pmset failed")
        // Right after a successful install.
        check(resultAfterInstall(sudoStderr: needsPassword) == .ruleOverridden, "after install, password -> overridden")
        check(resultAfterInstall(sudoStderr: notAllowed) == .ruleOverridden, "after install, not allowed -> overridden")
        check(resultAfterInstall(sudoStderr: "") == .pmsetFailed, "after install, silent -> pmset failed")
        check(!sudoRefused("SleepDisabled\t\t1\n"), "pmset output is not a sudo refusal")
    }

    // Audit 2026-10-23 Low: a VoiceOver press after the password box or an alert must still switch.
    static func clicks() {
        func act(mouseUp: Bool = true, otherWindow: Bool = false, seen: Bool = false, right: Bool = false,
                 control: Bool = false, time: TimeInterval = 100, ignoreUntil: TimeInterval = 50) -> ClickAction {
            clickAction(mouseUp: mouseUp, otherWindow: otherWindow, seenBefore: seen, right: right,
                        control: control, time: time, ignoreUntil: ignoreUntil)
        }
        // Real clicks on the button.
        check(act() == .toggle, "fresh left click switches")
        check(act(right: true) == .menu, "fresh right click opens the menu")
        check(act(control: true) == .menu, "fresh Control-click opens the menu")
        check(act(time: 40) == .ignore, "click queued behind the password box is dropped")
        check(act(right: true, time: 40) == .menu, "queued right click still opens the menu (as before)")
        // VoiceOver presses: the current event is stale.
        check(act(seen: true, time: 40) == .toggle, "stale old click (seen before) -> VoiceOver press switches")
        check(act(seen: true, right: true) == .toggle, "stale right click -> switches, not the menu")
        check(act(mouseUp: false, time: 40) == .toggle, "stale Return key from the alert -> switches")
        check(act(mouseUp: false, control: true) == .toggle, "stale Control-key event -> switches, not the menu")
        check(act(otherWindow: true, time: 40) == .toggle, "stale click on the alert's OK button -> switches")
        check(act(mouseUp: false, time: 0) == .toggle, "no current event at all -> switches")
    }

    // Audit 2026-10-23 Low: switching to awake with the lid already shut applies Lights Off.
    static func switchWithLidShut() {
        check(lightsOffAfterSwitch(result: .done, nowAwake: true, lidShut: true), "awake on, lid shut -> lights off")
        check(!lightsOffAfterSwitch(result: .done, nowAwake: true, lidShut: false), "awake on, lid open -> nothing")
        check(!lightsOffAfterSwitch(result: .done, nowAwake: false, lidShut: true), "back to normal, lid shut -> nothing")
        check(!lightsOffAfterSwitch(result: .cancelled, nowAwake: true, lidShut: true), "password cancelled -> nothing")
        check(!lightsOffAfterSwitch(result: .pmsetFailed, nowAwake: true, lidShut: true), "switch failed -> nothing")
    }

    // Audit 2026-10-23 Low: less always-on work. Light levels are read every 5 s in normal mode.
    static func polling() {
        let normalReads = (1...60).filter { readLevelsNow(tick: $0, awake: false) }.count
        let awakeReads = (1...60).filter { readLevelsNow(tick: $0, awake: true) }.count
        check(normalReads == 12, "normal mode: 12 reads a minute (was 60), got \(normalReads)")
        check(awakeReads == 60, "awake mode: still every second, got \(awakeReads)")
    }
}
