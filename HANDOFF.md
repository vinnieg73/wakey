# Wakey handoff

## Status
Working and in daily use. The first 2026-10-11 audit fixes are merged into `main` (PR #1) and installed in
`/Applications/Wakey.app`; Vinnie tested them on 2026-10-11.
A second audit (2026-10-11, report `tool-reviews/2026-10-11/wakey.md` in the project's shared files) is fixed,
merged into `main` (PR #2), built and installed in `/Applications/Wakey.app` on 2026-10-11 (compiled cleanly).
Hand-tested 2026-10-11: the new rule install works (old `/etc/sudoers.d/sleeptoggle` removed, one password prompt
installed `sleeptoggle-vinnie` root:wheel 0440, no staging file left), and a later click switched with no prompt.
Also tested: the VoiceOver "Show menu" action opens the menu without switching; Open at Login from a
build-folder copy refuses to turn on (alert shown, nothing registered). Only the lid-shut Lights Off toggle is left.
A third audit (2026-10-23, report `tool-reviews/2026-10-23/wakey.md`: 0 High, 1 Medium, 4 Low) is fixed on branch
`fix/audit-2026-10-23`. Not merged, not built or installed yet: see "Mac test plan (audit 2026-10-23)".
Repo: `vinnieg73/wakey` (private).

## Done
- Menu bar face toggles `pmset -a disablesleep 0|1` (orange/smiling = awake, blue/sleepy = normal sleep).
- One-time password prompt installs a sudo rule scoped to `pmset -a disablesleep 0|1` only.
- Right-click menu: state, switch, Lights Off When Lid Closes, Open at Login, Quit.
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
  alert instead of asking for the password again.
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

### Third audit fixes (2026-10-23, branch `fix/audit-2026-10-23`, not merged)
All 5 findings fixed, in the report's order. Nothing skipped. The decision rules moved into `Logic.swift`
(no AppKit), checked by `tests/LogicTests.swift` via `tests/run.sh` (34 checks).
1. Medium, the "rule already works" check. The old `sudo -n -l pmset ...` passed whenever any rule allows pmset
   and any one entry has NOPASSWD, so with another no-password rule Wakey never installed its own rule and kept
   saying "pmset itself failed". Now a failure counts as pmset's own only when Wakey's rule file (or the legacy
   `/etc/sudoers.d/sleeptoggle`) exists and `sudo -n`'s stderr is not sudo refusing ("a password is required",
   "not allowed to execute", a `sudo:` line). Otherwise it asks for the password as before. If sudo still refuses
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
   normal mode the saved light level lags by ~15 s instead of ~3 s.
5. Low (optional), dimmed screen saved. A screen reading is not kept when there's been no keyboard, mouse or
   trackpad input for 10 s (`CGEventSource.secondsSinceLastEventType`) or the built-in display is asleep
   (`CGDisplayIsAsleep`). Keyboard readings are unchanged.

How it was tested (Linux, no Mac): `tests/run.sh` with a Swift 5.10 toolchain, 34 passed / 0 failed;
`swiftc -parse` on all four Swift files; and a type-check of `main.swift` + `Logic.swift` against stub
AppKit/ServiceManagement modules (scratch only, not in the repo), clean. `Lid.swift`'s two additions
(`userIdleSeconds()`, `ScreenLight.isAsleep`) were only parsed, not type-checked. Nothing ran on the Mac.

## Mac test plan (audit 2026-10-23)
Everything Claude runs is in the background: no `open` of the build-folder copy, no windows on Vinnie's screen.
The hand tests (clicks, VoiceOver, the lid) are for Vinnie to do himself.

1. Checks and a hidden build (Claude can run these, in the background):
   ```bash
   cd ~/path/to/wakey && git fetch origin && git checkout fix/audit-2026-10-23
   tests/run.sh          # expect "34 passed, 0 failed"
   ./build.sh            # compiles only, never launches; expect "Built build.noindex/Wakey.app"
   ```
   If the compile fails, `/Applications/Wakey.app` is untouched (build.sh compiles to a temp file first).
2. The sudo check, without touching sudoers (read-only commands; nothing is written to `/etc/sudoers.d`):
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
3. Install (needs Vinnie's OK, it replaces his running copy; menu bar only, no windows):
   ```bash
   osascript -e 'quit app "Wakey"'; while pgrep -xq Wakey; do sleep 0.2; done
   rm -rf /Applications/Wakey.app && cp -R build.noindex/Wakey.app /Applications/ && open -g /Applications/Wakey.app
   ```
   Check no privacy prompt appears (the idle-time read needs none; if an Input Monitoring prompt shows, report it).
4. Hand tests (Vinnie):
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
Merge `fix/audit-2026-10-23` into `main` after the Mac test plan passes, then install as in step 3 above.
No sudoers change is needed: the existing `sleeptoggle-vinnie` rule keeps working.

## Next steps
- Run the Mac test plan (audit 2026-10-23) above, then merge and install.
- Still to hand-test (needs the lid physically shut): with awake mode on, close the lid, then untick and re-tick
  Lights Off When Lid Closes from the menu (via an external display or VoiceOver). Unticking should stop holding the
  keyboard light at 0; ticking should turn the lights off right away.

## Decisions
- Keep the display-off on lid close (2026-10-10). Vinnie wants the Mac to lock when the lid closes;
  don't remove or default-off that behavior.
- Known, not fixed (by choice): Sidecar and other virtual displays count as external displays.
  The 1x icon outlines look slightly soft.

## Open decisions
- None.

## Gotchas
- Display-off trips the lock screen when System Settings > Lock Screen requires a password after the
  display turns off. That's a lock, not sleep. Check with:
  `pmset -g log | grep -E "Entering Sleep|Wake from|DarkWake|Display is turned" | tail -40`
- With an external display attached, closing the lid only turns the keyboard light off. The screens
  stay on (clamshell mode).
- `disablesleep` survives quit and reboot. Switch it back off when done, or the Mac never sleeps.
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
