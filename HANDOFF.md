# Wakey handoff

## Status
Working and in daily use. Repo: `vinnieg73/wakey` (private), branch `main`. Installed copy lives in `/Applications/Wakey.app`.

## Done
- Menu bar face toggles `pmset -a disablesleep 0|1` (orange/smiling = awake, blue/sleepy = normal sleep).
- One-time password prompt installs `/etc/sudoers.d/sleeptoggle`, scoped to `pmset -a disablesleep 0|1` only.
- Right-click menu: state, switch, Open at Login, Lights Off When Lid Closes, Quit.
- Lights Off When Lid Closes (default on, only while awake mode is on): on lid close it runs
  `pmset displaysleepnow` and turns the keyboard backlight to 0; restores on lid open or quit.
- Verified 2026-10-10: with awake mode on and lid closed from 10:05 to 16:16 EDT, the pmset log has
  zero "Entering Sleep" entries (none at all since Oct 3). The Mac stayed awake; the display just turned off.

## Next steps
- None required.

## Decisions
- Keep the display-off on lid close (2026-10-10). Vinnie wants the Mac to lock when the lid closes;
  don't remove or default-off that behavior.

## Open decisions
- None.

## Gotchas
- Display-off trips the lock screen when System Settings > Lock Screen requires a password after the
  display turns off. That's a lock, not sleep. Check with:
  `pmset -g log | grep -E "Entering Sleep|Wake from|DarkWake|Display is turned" | tail -40`
- `disablesleep` survives quit and reboot. Switch it back off when done, or the Mac never sleeps.
- `pmset -g` shows `SleepDisabled 1` when awake mode is on.
- Auto-brightness can relight the keyboard while the lid is closed; `checkLid()` re-zeros it.
- Undo the sudo rule: `sudo rm /etc/sudoers.d/sleeptoggle`.
- Build output goes to `build.noindex/` so Spotlight doesn't index a second Wakey.app.
