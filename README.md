# Wakey

A menu bar switch that keeps your Mac awake, even with the lid closed.

- **Click** the face to switch: orange and smiling = staying awake, blue and sleepy = normal sleep.
- **Right-click** for the menu:
  - the current state (just a label),
  - the switch (Keep Awake with Lid Closed / Allow Sleep Again),
  - **Lights Off When Lid Closes** (on by default),
  - **Open at Login**,
  - **Quit Wakey**.

## Lights Off When Lid Closes

Only works in awake mode. When you close the lid, Wakey turns the keyboard light off and the screen off.
Turning the screen off locks the Mac. That is on purpose.
If an external display is attached, only the keyboard light goes off (the screens stay on).
The lights come back when you open the lid. If Wakey quits (or crashes) while the lid is shut, they come
back the next time Wakey starts instead.

## How switching works

It uses `pmset -a disablesleep`. Switching needs an administrator account. The first switch asks for
that password once and installs a rule file, `/etc/sudoers.d/sleeptoggle-<username>` (one file per user).
The rule lets your user run only `pmset -a disablesleep 0|1` without a password.
Older installs may have `/etc/sudoers.d/sleeptoggle` instead. It still works.
The setting survives quitting and restarts, so switch sleep back on when you're done.

## Build and install

Quit Wakey first and remove the old app, then copy the new one. Copying over the running app can leave
it running old code, or get it killed.

```bash
./build.sh                                   # builds build.noindex/Wakey.app
osascript -e 'quit app "Wakey"'
while pgrep -xq Wakey; do sleep 0.2; done    # wait until the old copy has exited
rm -rf /Applications/Wakey.app
cp -R build.noindex/Wakey.app /Applications/
open /Applications/Wakey.app
./make-icon.sh                               # only if the face changes: regenerates AppIcon.icns
```

## Undo

Turn sleep back on first, or the Mac will never sleep.

1. Switch Wakey to normal sleep (or run `sudo pmset -a disablesleep 0`).
2. Quit Wakey. Turn off Open at Login (System Settings > General > Login Items), or delete the app.
3. Remove the rule file:

```bash
sudo sh -c 'rm -f /etc/sudoers.d/sleeptoggle /etc/sudoers.d/sleeptoggle-*'
```
