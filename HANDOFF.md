# Wakey handoff

## Status
Working and in daily use. Everything is on `main`: three audits fixed and merged (PRs #1, #2, #3), the self-check
(PR #4), the 2026-11-09 sweep (docs, version number and cleanup), Version 1.1 and Version 1.2 (see those sections).
Current: Version 1.2, tagged `v1.2` and installed in `/Applications/Wakey.app` on 2026-11-09. (Version 1.1, the
first numbered release, was tagged `v1.1` and installed earlier the same evening.)
Owner thread: "Work on Wakey with Fable" in the Utilities project.

### How it got here
The first 2026-10-11 audit fixes are merged into `main` (PR #1) and installed in
`/Applications/Wakey.app`; Vinnie tested them on 2026-10-11.
A second audit (2026-10-11, report `tool-reviews/2026-10-11/wakey.md` in the project's shared files) is fixed,
merged into `main` (PR #2), built and installed in `/Applications/Wakey.app` on 2026-10-11 (compiled cleanly).
Hand-tested 2026-10-11: the new rule install works (old `/etc/sudoers.d/sleeptoggle` removed, one password prompt
installed `sleeptoggle-vinnie` root:wheel 0440, no staging file left), and a later click switched with no prompt.
Also tested: the VoiceOver "Show menu" action opens the menu without switching; Open at Login from a
build-folder copy refuses to turn on (alert shown, nothing registered). Only the lid-shut Lights Off toggle is left.
A third audit (2026-10-23, report `tool-reviews/2026-10-23/wakey.md`: 0 High, 1 Medium, 4 Low) is fixed, merged
into `main` (PR #3, 2026-10-22 23:21) and installed (built 23:23 after the merge, installed 23:24). Steps 1 to 3
of "Mac test plan (audit 2026-10-23)" are done; the hand tests in step 4 are not recorded as done.
Repo: `vinnieg73/wakey` (private).
2026-10-25: one self-check command, `./selfcheck.sh` (merged, PR #4): `tests/run.sh` then `./build.sh` (compile into
build.noindex, no launch); PASS / FAIL (n), exit 0/1; without swiftc it prints "needs a Mac" and exits 2.
First run on the Mac 2026-11-09: "38 passed, 0 failed", "Built build.noindex/Wakey.app", PASS. See README "Self-check".

## Sweep (2026-11-09)
Vinnie asked for a full read of the project: find what's broken, inconsistent, inefficient or no longer needed.
Every file was read; the Mac ran the checks hidden in the background.
- Code: no new bugs found. `./selfcheck.sh` PASS on the Mac (first Mac run). `swiftc -typecheck` on the (then) four
  source files: no warnings (Swift 6.4.2, macOS 27.2).
- Cost of running: 7 min 14 s of CPU in 4 days 5 hours of uptime (about 0.1% of one core), 13 MB of memory.
  The once-a-second lid check is cheap enough to leave alone.
- sudo wording on macOS 27.2 is still "sudo: a password is required" (what `sudoRefused()` matches).
- No leftovers on the Mac: one prefs file (`com.vinnie.wakey`, 4 keys, all in use), one rule file
  (`sleeptoggle-vinnie`, root:wheel 0440), no old "Sleep Toggle" app, no legacy rule file.
- Fixed: the stale lines in this file; README build steps (`make-icon.sh` was listed after the install, it has
  to run before `build.sh`; `open -g`); a version and build number in `build.sh` (there was no build number at all).
- Removed, not used by anything: `awake-eyes-mockups.png`, `icon-preview-awake.png`, `icon-preview-sleep.png`
  (left over from the first commit; still in git history). `icon-preview-app.png` stays: `make-icon.sh` writes it.
- Left for Vinnie: see "Open decisions". He said "go ahead" on the first two (Quit, Help): see "Version 1.1".

## Version 1.1 (2026-11-09)
Two changes Vinnie approved from the sweep list, plus the sweep itself.
- Quit from the menu switches back to normal sleep first (`quitFromMenu()` in `main.swift`). While orange the
  row reads "Quit and Allow Sleep Again". If the switch fails or the password box is cancelled, an alert asks
  "Don't Quit" / "Quit Anyway". A restart, a logout and `quit app "Wakey"` (the install steps) don't go through
  the menu, so they keep the setting: awake mode still survives a reboot and an install.
- "Wakey Help" in the menu (`Help.swift`): a standard alert with the app icon, "Version 1.1", and short text with
  the two faces next to their lines. Text is grayscale; the only color is the faces themselves.
- A separator now sits above Help and Quit.
- Rules in `Logic.swift` (`quitTitle`, `quitNeedsWarning`), 7 new checks: `tests/run.sh` says "45 passed, 0 failed".
- How it was tested: `./selfcheck.sh` PASS on the Mac. The Help alert was rendered to a picture off screen and
  looked at (no window opened). Vinnie then sent a screenshot of the real Help window (dark mode): it renders as
  intended. The new Quit is not hand-tested yet: see "Next steps".

## Version 1.2 (2026-11-09)
One cosmetic fix from Vinnie's Help screenshot, which he asked to ship.
- In Wakey Help, the two lines that start with a face wrapped back under the face. They now wrap under their own
  text (a hanging indent: `headIndent` on those two paragraphs only, in `helpText()` in `Help.swift`).
- No change to behavior, wording or the other lines. Tests unchanged (45).

## Version
Two numbers, set once at the top of `build.sh` (`VERSION`). The build number (CFBundleVersion) is worked out
from it: major x 100 + minor, so 1.2 = 102. Each release bumps the second number and gets a git tag
(`v1.2`), pushed. Say "Version 1.2", never "1.2 (102)". Before 2026-11-09 every build said 1.0 with no build number.
The next release is 1.3.

## Done
- Menu bar face toggles `pmset -a disablesleep 0|1` (orange/smiling = awake, blue/sleepy = normal sleep).
- One-time password prompt installs a sudo rule scoped to `pmset -a disablesleep 0|1` only.
- Right-click menu: state, switch, Lights Off When Lid Closes, Open at Login, Wakey Help, Quit.
- Lights Off When Lid Closes (default on, only while awake mode is on): on lid close it runs
  `pmset displaysleepnow` and turns the keyboard backlight to 0; lights come back on lid open.
- Verified 2026-10-10 (before the audit fixes): with awake mode on and lid closed from 10:05 to 16:16 EDT,
  the pmset log has zero "Entering Sleep" entries. The Mac stayed awake; the display just turned off.

### Audit fixes (merged 2026-10-11, tested on the Mac)
- Lights are restored only if Wakey was the one that dimmed them.
- It never saves a keyboard level of 0 as the level to come back to.
- A "lights are off" flag is saved to disk. If Wakey crashes, the next launch brings the lights back
  (or waits for the lid to open, if the lid is shut).
- Quitting with the lid closed does not relight the keyboard.
- A click reads the real sleep state first, not a cached one.
- If a switch fails, Wakey shows an alert. Cancelling the password box stays silent.
- Clicks queued behind the password box are ignored.
- Login item: retries on the next launch if it failed, shows the approval prompt in System Settings
  when needed, and only registers from `/Applications` (not the build folder).
- Sudo rule is now one file per user, `/etc/sudoers.d/sleeptoggle-<username>`. It is installed in a
  staging file, checked with `visudo`, then moved into place.
- Timers run in common mode, so they keep going while the menu is open.
- App Nap opt-out, so the lid check isn't delayed.
- Only one Wakey runs at a time.
- Opening the app again brings back a hidden menu bar icon.
- `build.sh` and `make-icon.sh` are safer: a failed compile no longer wipes the old app, they work from
  their own folder (even through a symlink), and they clean up after themselves.

### Second audit fixes (merged 2026-10-11, installed, rule install tested)
- Rule install: no temp file anymore. The root shell writes the exact rule text into a root-owned
  staging file in `/etc/sudoers.d`, sets root:wheel 0440, checks it with `visudo -cf`, then moves it
  into place. Same narrow rule, same file name.
- If `pmset` fails but `sudo -n -l` shows the rule already allows it, Wakey shows a "pmset itself failed"
  alert instead of asking for the password again. (Replaced in the third audit: the `sudo -n -l` check was
  wrong, see fix 1 below.)
- Clicks while the failure alert is open can't start another switch.
- VoiceOver: the menu bar button has a "Show menu" action (VO-Command-Space on the button). A normal
  click or VoiceOver press still switches.
- Open at Login from the menu: refuses (with an alert) outside `/Applications`; turning it on or off marks
  the login setup as done, so a later launch won't re-register it.
- Lights Off menu item works with the lid shut: unticking stops holding the keyboard light at 0,
  ticking turns the lights off right away.
- Docs: Undo command is zsh-safe, upgrade steps wait for the old copy to quit, README says the lights come
  back on the next launch if Wakey quits with the lid shut. `make-icon.sh` now follows symlinks.
- Not fixed, by choice: #8 (a keyboard light you turned off yourself is relit after a lid cycle; needs a
  design choice since manual-off looks like idle-off), #9 (Normal-mode save/settle; not provable, and the
  Mac sleeps at lid close in Normal mode anyway), #10 (rule file name collision for names like `a.b`/`a_b`;
  rare, no privilege gain, and renaming would re-prompt everyone).

### Third audit fixes (2026-10-23, merged as PR #3 and installed 2026-10-22 23:24)
All 5 findings fixed, in the report's order. Nothing skipped. The decision rules moved into `Logic.swift`
(no AppKit), checked by `tests/LogicTests.swift` via `tests/run.sh` (38 checks).
1. Medium, the "rule already works" check. The old `sudo -n -l pmset ...` passed whenever any rule allows pmset
   and any one entry has NOPASSWD, so with another no-password rule Wakey never installed its own rule and kept
   saying "pmset itself failed". Now a failure counts as pmset's own only when Wakey's rule file (or the legacy
   `/etc/sudoers.d/sleeptoggle`) exists and `sudo -n`'s stderr is not sudo refusing ("a password is required",
   "not allowed to execute", or sudo rejecting a sudoers file: bad mode or owner, parse error). Otherwise it asks for the password as before. If sudo still refuses
   right after a successful install, the alert now says another sudo rule overrides Wakey's. The rule install
   itself (root-owned staging file, umask 0337, root:wheel 0440, `visudo -cf`, atomic `mv`) is unchanged.
2. Low, VoiceOver presses. The queued-click time check and the right-click/Control check now apply only to a new
   mouse-up on the button (not an event the button already saw, not one from another window such as the alert).
   Any other press switches. Before, the stale event left behind by the password box or alert dropped the press.
3. Low, switching to awake with the lid already shut (clamshell) now runs Lights Off right away
   (`lightsOff()` still checks the setting and the real sleep state; the lid is read fresh).
4. Low, polling. Reduced, not replaced: the state timer is 15 s (was 5 s) and no longer asks SMAppService
   (that XPC call happens only when the menu opens or after a change). The lid check stays at 1 s, so lid
   edges are caught as before, but in normal mode it reads the light levels only every 5th second. Timers have
   a tolerance (3 s, 0.2 s). Not switched to an IOKit lid notification (`kIOPMMessageClamshellStateChange`):
   it can't be tried without the Mac, and `checkLid()` would still need its timer to re-zero the keyboard and
   sample levels. Trade-offs: a change made in Terminal shows on the icon within ~15 s instead of ~5 s; in
   normal mode the saved light level lags by ~15 s instead of ~3 s; after an out-of-Wakey switch to awake,
   Wakey reads levels at the normal-mode rate until its next 15 s state poll.
5. Low (optional), dimmed screen saved. A screen reading is not kept when there's been no keyboard, mouse or
   trackpad input for 30 s (`CGEventSource.secondsSinceLastEventType`) or the built-in display is asleep
   (`CGDisplayIsAsleep`). Keyboard readings are unchanged (a keyboard light caught mid-fade by "turn off after
   inactivity" can still be saved; that was not in the report). 30 s is a guess at "before the dim": display sleep
   is at least 1 minute of idle; the Mac test plan checks it.

How it was tested (Linux, no Mac): `tests/run.sh` with a Swift 5.10 toolchain, 38 passed / 0 failed;
`swiftc -parse` on all four Swift files; a bug review of the diff (the code-review skill; the Agent tool for a
separate helper wasn't available in that session), whose real findings were fixed (window check by window number,
no "sudo:" prefix rule since sudo warnings still run pmset, settling counted in seconds, 30 s idle limit);
and a type-check of `main.swift` + `Logic.swift` against stub
AppKit/ServiceManagement modules (scratch only, not in the repo), clean. `Lid.swift`'s two additions
(`userIdleSeconds()`, `ScreenLight.isAsleep`) were only parsed, not type-checked. Nothing ran on the Mac
at the time. Since then: built and installed on the Mac 2026-10-22, and `./selfcheck.sh` passed there 2026-11-09.

## Off-state check (2026-10-23, read-only, nothing changed)
Question: with Wakey off, does the Mac sleep like stock macOS?
- Code: the only power setting Wakey ever writes is `pmset -a disablesleep 0|1`. `displaysleepnow` is a one-shot
  (screen off now), not a setting. It never touches `sleep`, `displaysleep`, `disksleep` etc., never runs
  `caffeinate`, and never creates an IOPM assertion. Its `beginActivity(.userInitiatedAllowingIdleSystemSleep)`
  (App Nap opt-out) allows sleep and does not show in `pmset -g assertions`.
- Live, Wakey running in normal mode: `SleepDisabled 0`; no Wakey entry in `pmset -g assertions`; no
  `caffeinate` running; Claude Dashboard running but holding no assertion. Wakey leaves nothing behind when off.
- Gap: quitting Wakey while awake mode is on leaves `SleepDisabled 1` (documented, `applicationWillTerminate`
  only restores lights). Switch to normal before quitting. Changing that is Vinnie's call.
  (Closed in Version 1.1: the menu's Quit switches back first.)
- Not Wakey: AC Power has `sleep 0` and `displaysleep 0` (on the charger: never idle-sleep, never turn the screen
  off); battery has `displaysleep 30`. No version of Wakey in git history ever set these, and its sudo rule only
  allows `disablesleep`. They match System Settings > Lock Screen "Turn display off on power adapter when inactive:
  Never" and Battery > Options "Prevent automatic sleeping on power adapter when the display is off". They don't
  stop lid-close sleep. The Claude app also holds a NoIdleSleepAssertion
  ("sleep prevented by Claude"), which blocks idle sleep only.
- Lid test passed (2026-10-23, by Vinnie): blue face, no external display, on AC. Log: 14:30:32 "Entering Sleep
  state due to 'Clamshell Sleep'", a 10 s DarkWake (normal Wi-Fi/maintenance wake), back to sleep 14:30:44,
  "Wake from Deep Idle ... lid" at 14:32:41. `SleepDisabled` still 0 after. Off mode sleeps like stock macOS.

## Check after AlDente (2026-10-25, read-only)
Vinnie installed AlDente, then removed it (`brew uninstall --zap --cask` while it was open); macOS's own 80% limit is on.
- Wakey unaffected: binary unchanged (same SHA-1 as 2026-10-23), signature valid, running. Rule file
  `sleeptoggle-vinnie` unchanged (root:wheel 0440, same date). `sudo -n pmset -a disablesleep <current>` exit 0
  while plain `sudo -n` still needs a password, so the rule works. Awake mode was on (`SleepDisabled 1`).
- AlDente gone: no process, helper, launch daemon or agent, or power assertion. Only leftover is
  `~/Library/Preferences/com.apphousekitchen.aldente-pro.plist` (settings only; `hasBeenActivated` false).
- Battery 98%, "AC attached; not charging" is expected with an 80% limit. If it still won't charge below 80%,
  suspect a stuck AlDente charge setting; a restart clears it.

## Mac test plan (audit 2026-10-23)
Everything Claude runs is in the background: no `open` of the build-folder copy, no windows on Vinnie's screen.
The hand tests (clicks, VoiceOver, the lid) are for Vinnie to do himself.

1. DONE 2026-11-09 (`./selfcheck.sh` on `main`: PASS). Checks and a hidden build (Claude can run these, in the background):
   ```bash
   cd ~/Code/Utilities/SleepToggle && ./selfcheck.sh   # expect "45 passed, 0 failed", "Built build.noindex/Wakey.app", PASS
   ```
   If the compile fails, `/Applications/Wakey.app` is untouched (build.sh compiles to a temp file first).
2. DONE (2026-10-25 "Check after AlDente": the rule works and plain `sudo -n` is refused; 2026-11-09: the refusal
   text is "sudo: a password is required"). The sudo check, without touching sudoers (read-only commands; nothing is written to `/etc/sudoers.d`):
   ```bash
   ls -l /etc/sudoers.d/                         # sleeptoggle-vinnie root:wheel 0440; Wakey only checks that it exists
   sudo -k
   sudo -n -l /usr/bin/true; echo "list exit $?"  # the old check's flaw: expect exit 0 (Wakey's NOPASSWD entry is enough)
   sudo -n /usr/bin/true; echo "run exit $?"      # expect "sudo: a password is required", exit 1
   v=$(pmset -g | awk '/SleepDisabled/{print $2}')
   sudo -n /usr/bin/pmset -a disablesleep "$v"; echo "pmset exit $?"   # sets the current value again: exit 0, no output
   ```
   The `-l` line is the false positive the audit found: `sudo -n -l` says yes for a command sudo then refuses
   (if it fails instead, this Mac's sudo doesn't show the flaw; the fix doesn't depend on it either way).
   The `sudo -n /usr/bin/true` line's text must contain "password" (that's what `sudoRefused()` matches). If macOS prints
   something else there, add it to `tests/LogicTests.swift` and `sudoRefused()`.
   A real fresh install (no rule file) can only be tried on another account: optional, by Vinnie, with a spare
   admin test user (log in as it, run Wakey from `/Applications`, click: expect one password box, then switching
   with no box; then remove `/etc/sudoers.d/sleeptoggle-<testuser>` and delete the test user).
3. DONE 2026-10-22 23:24 for the audit build. The same steps install any later build. Install (needs Vinnie's OK, it replaces his running copy; menu bar only, no windows):
   ```bash
   osascript -e 'quit app "Wakey"'; while pgrep -xq Wakey; do sleep 0.2; done
   rm -rf /Applications/Wakey.app && cp -R build.noindex/Wakey.app /Applications/ && open -g /Applications/Wakey.app
   ```
   Check no privacy prompt appears (the idle-time read needs none; if an Input Monitoring prompt shows, report it).
4. NOT recorded as done. Hand tests (Vinnie):
   - Left click switches; right-click and Control-click open the menu (checks the new click filter didn't break
     real clicks).
   - VoiceOver on: press the button (VO-Space) twice in a row; each press switches. Then cause the failure alert
     (or cancel the password box on a test account), close it with Return, and press with VoiceOver again: it
     switches. VO-Command-Space "Show menu" still opens the menu.
   - Clamshell: lid shut with an external display, Wakey in normal mode, switch to awake from the external display:
     the keyboard light goes off right away (and stays off). Open the lid: it comes back.
   - Dim: with the lid open, leave the Mac idle until the screen dims, then close and reopen the lid in awake mode:
     the screen comes back at the normal level, not the dim one.
   - Polling: run `sudo pmset -a disablesleep 1` in Terminal; the icon turns orange within ~15 s. Switch back.
     Optional: `top -l 2 -pid $(pgrep -x Wakey) -stats pid,cpu,idlew` to compare idle wakeups with the old build.

## Deploy
Work on `main` (or a short branch merged into it). Before every commit: `./selfcheck.sh` must say PASS, and this
file, the README and any in-app text must match the change. Bump `VERSION` in `build.sh` for a release and tag it.
Commits, pushes and installs need Vinnie's own typed OK. Install as in step 3 of the Mac test plan.
No sudoers change is needed: the existing `sleeptoggle-vinnie` rule keeps working.

## Next steps
- Run `./selfcheck.sh` before every commit (it passed on the Mac 2026-11-09).
- Hand test still open (Vinnie): while orange, the last menu row reads "Quit and Allow Sleep Again"; choose it,
  then `pmset -g | grep SleepDisabled` says 0 and reopening Wakey shows the blue face. (Wakey Help itself is
  checked: his screenshot of Version 1.1, 2026-11-09. A screenshot of 1.2's face lines would confirm the indent.)
- Hand tests in step 4 of the Mac test plan (audit 2026-10-23), by Vinnie; everything else in that plan is done.
- Still to hand-test (needs the lid physically shut): with awake mode on, close the lid, then untick and re-tick
  Lights Off When Lid Closes from the menu (via an external display or VoiceOver). Unticking should stop holding the
  keyboard light at 0; ticking should turn the lights off right away.

## Decisions
- Keep the display-off on lid close (2026-10-10). Vinnie wants the Mac to lock when the lid closes;
  don't remove or default-off that behavior.
- Known, not fixed (by choice): Sidecar and other virtual displays count as external displays.
  The 1x icon outlines look slightly soft.

## Open decisions
All Vinnie's call; listed for him in the 2026-11-09 sweep. Nothing here is built.
- Screen may come back on under the shut lid: Wakey turns the display off once at lid close and re-darkens only
  the keyboard after that. On the charger the display never sleeps by itself (`displaysleep 0`), so if something
  wakes it (charger plugged in, a notification, an external display unplugged) it may stay lit until the lid
  opens. Plausible, not proven. Suggested: `checkLid()` also re-runs `displaysOffNow()` when the lid is shut,
  the lights are meant to be off, no external display is attached and the built-in display is awake. Needs a
  lid test on the Mac. Careful: every display-off locks the Mac, so a repeat must not fight someone using the
  Mac remotely with the lid shut. The `pmset -g log` display lines (2026-11-09) could not confirm or rule it out.
- Low battery with the lid shut: nothing switches awake mode off, so the Mac in a bag while orange runs until
  empty. Idea: switch back to normal sleep below a set battery level when on battery.
- Efficiency, optional and tiny: the state could be read from IOKit (`IOPMrootDomain` has `SleepDisabled`,
  checked 2026-11-09) instead of running `pmset -g` every 15 s; the lid could come from an IOKit notification
  instead of a 1 s timer. Measured cost today is about 0.1% of one core, so the gain is small.
- Still open from the second audit, by choice: a keyboard light Vinnie turned off himself is relit after a
  lid cycle (#8); rule file name collision for odd user names (#10).

## Gotchas
- Display-off trips the lock screen when System Settings > Lock Screen requires a password after the
  display turns off. That's a lock, not sleep. Check with:
  `pmset -g log | grep -E "Entering Sleep|Wake from|DarkWake|Display is turned" | tail -40`
- With an external display attached, closing the lid only turns the keyboard light off. The screens
  stay on (clamshell mode).
- `disablesleep` survives a reboot, and any quit that isn't the menu's Quit (a kill, `quit app`, a crash).
  Switch it back off when done, or the Mac never sleeps. The menu's Quit switches it back for you.
- Adding a Swift file: list it on the `swiftc` line in `build.sh` (five files now, `Help.swift` is the newest).
- `pmset -g` shows `SleepDisabled 1` when awake mode is on. Wakey polls it every 15 s (a click and the menu read it fresh).
- Don't go back to `sudo -n -l` to ask "does the rule work?": it passes whenever any entry has NOPASSWD.
- Auto-brightness can relight the keyboard while the lid is closed; `checkLid()` re-zeros it.
- The sudo rule file is now `/etc/sudoers.d/sleeptoggle-<username>`. Older installs may still have
  `/etc/sudoers.d/sleeptoggle`, which still works.
- Undo: turn sleep back on first (`sudo pmset -a disablesleep 0`), quit Wakey, turn off Open at Login,
  then `sudo sh -c 'rm -f /etc/sudoers.d/sleeptoggle /etc/sudoers.d/sleeptoggle-*'` (the quotes keep zsh
  from stopping on an unmatched glob).
- Quitting with the lid shut and the lights off leaves the keyboard dark until Wakey starts again
  (on purpose, so a crash can't strand it the other way).
- The menu's Open at Login only works from `/Applications`.
- Overwriting the running app in place can leave old code running or get it killed. Quit and `rm -rf`
  the old app before copying.
- Build output goes to `build.noindex/` so Spotlight doesn't index a second Wakey.app.
