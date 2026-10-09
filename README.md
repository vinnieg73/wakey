# Wakey

A menu bar switch that keeps your Mac awake, even with the lid closed.

- **Click** the face to switch: orange and smiling = staying awake, blue and sleepy = normal sleep.
- **Right-click** for the menu: state, switch, Open at Login, Quit.

It uses `pmset -a disablesleep`. The first switch asks for your password once and installs
`/etc/sudoers.d/sleeptoggle`, which lets your user run only `pmset -a disablesleep 0|1` without a password.
The setting survives quitting and restarts, so switch sleep back on when you're done.

## Build

```bash
./build.sh                         # builds build.noindex/Wakey.app
cp -R build.noindex/Wakey.app /Applications/
./make-icon.sh                     # only if the face changes: regenerates AppIcon.icns
```

## Undo

```bash
sudo rm /etc/sudoers.d/sleeptoggle
```
