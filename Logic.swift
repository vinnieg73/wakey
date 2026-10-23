// Wakey's decision rules, kept free of AppKit so tests/run.sh can build and check them on their own.
import Foundation

enum SwitchResult { case done, cancelled, failed, pmsetFailed, ruleOverridden }

/// True when stderr from `sudo -n` is sudo itself refusing (it wants a password, or no rule allows
/// the command), not an error printed by pmset.
func sudoRefused(_ stderr: String) -> Bool {
    let s = stderr.lowercased()
    return s.contains("password")                          // "sudo: a password is required"
        || s.contains("not allowed to execute")            // "Sorry, user x is not allowed to execute ..."
        || s.contains("not in the sudoers")
        || s.split(separator: "\n").contains { $0.hasPrefix("sudo:") }
}

/// After `sudo -n pmset` failed: the failure is pmset's own only when Wakey's rule file (or the legacy one)
/// is there and sudo did not refuse. Anything else needs the password prompt and the rule (re)installed.
func failureNeedsRule(ruleFileExists: Bool, sudoStderr: String) -> Bool {
    !ruleFileExists || sudoRefused(sudoStderr)
}

/// After the rule was just installed and `sudo -n pmset` still failed.
func resultAfterInstall(sudoStderr: String) -> SwitchResult {
    sudoRefused(sudoStderr) ? .ruleOverridden : .pmsetFailed   // refused: a later sudoers rule wins over Wakey's
}

enum ClickAction: Equatable { case toggle, menu, ignore }

/// What a press on the menu bar button does. `mouseUp`: the app's current event is a mouse-up.
/// `otherWindow`: that event belongs to another window (an alert's button). `seenBefore`: the same event
/// already reached the button once. An accessibility (VoiceOver) press has no event of its own and
/// leaves the last handled event in place, so only a new mouse-up on the button is treated as a click:
/// everything else switches, with no queued-click or Control check.
func clickAction(mouseUp: Bool, otherWindow: Bool, seenBefore: Bool, right: Bool, control: Bool,
                 time: TimeInterval, ignoreUntil: TimeInterval) -> ClickAction {
    guard mouseUp, !otherWindow, !seenBefore else { return .toggle }
    if right || control { return .menu }
    return time < ignoreUntil ? .ignore : .toggle   // queued behind the password box or the alert
}
