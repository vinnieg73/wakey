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
}
