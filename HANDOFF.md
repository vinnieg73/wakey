# Wakey handoff

## Status
Audit fixes are on branch `fix/audit-2026-10-11`. They are NOT built or tested on the Mac yet
(there is no Swift compiler in the cloud). `main` is the last version that was tested and in daily use.
Repo: `vinnieg73/wakey` (private). Installed copy lives in `/Applications/Wakey.app`.
The audit report is in the project's shared files as `wakey-audit-2026-10-11.md`.

## Done
- Menu bar face toggles `pmset -a disablesleep 0|1` (orange/smiling = awake, blue/sleepy = normal sleep).
- One-time password prompt installs a sudo rule scoped to `pmset -a disablesleep 0|1` only.
- Right-click menu: state, switch, Lights Off When Lid Closes, Open at Login, Quit.
- Lights Off When Lid Closes (default on, only while awake mode is on): on lid close it runs
  `pmset displaysleepnow` and turns the keyboard backlight to 0; lights come back on lid open.
- Verified 2026-10-10 (before the audit fixes): with awake mode on and lid closed from 10:05 to 16:16 EDT,
  the pmset log has zero "Entering Sleep" entries. The Mac stayed awake; the display just turned off.

### Audit fixes (branch fix/audit-2026-10-11, untested)
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

## Next steps
1. On the Mac, build from the branch: `./build.sh`.
2. Quit Wakey, remove the old app, copy the new one to `/Applications`, open it (see README).
3. Test in awake mode: close the lid, check keyboard light and screen go off; open it, check they come back.
4. Test one toggle (awake and back to normal sleep).
5. If all is good, merge `fix/audit-2026-10-11` into `main`.

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
  then `sudo rm -f /etc/sudoers.d/sleeptoggle /etc/sudoers.d/sleeptoggle-*`.
- Overwriting the running app in place can leave old code running or get it killed. Quit and `rm -rf`
  the old app before copying.
- Build output goes to `build.noindex/` so Spotlight doesn't index a second Wakey.app.
