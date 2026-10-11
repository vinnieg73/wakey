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

## Next steps
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
- `pmset -g` shows `SleepDisabled 1` when awake mode is on.
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
