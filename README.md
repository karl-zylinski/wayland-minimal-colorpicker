# Minimal color picker for Wayland

<img width="392" height="283" alt="image" src="https://github.com/user-attachments/assets/e3cb95fc-35ae-4559-98e1-b8e748e7a52e" />

Tested on KDE, but may also work on other compositors that support `zwlr_screencopy_manager_v1`. Does not work on GNOME.

- Compile using [Odin](https://odin-lang.org/): `odin build . -o:speed`
- Start the built executable and click anywhere to pick the color under the crosshair. The picked color goes into the clipboard.
- The program stays alive in the background until something else is copied into the clipboard. This is because Wayland needs the "clipboard source application" to stay alive. The background program will use 0% CPU.
- To swap between Hex and RGB modes, start the picker again while it is shown on the screen. The second instance will use a socket to tell the first instance that it needs to switch mode. The second instance will thereafter shut down. The program remembers the most recent mode using `$XDG_STATE_HOME/minimal_colorpicker` or `~/.local/state/minimal_colorpicker`.

Recommended: Assign a system wide hotkey such as `Shift+Meta+C` to run the program.

## KDE specifics

On KDE, the program uses KWin to pick the color. KWin won't let the color picker grab pixels unless it is pointed out by a `.desktop` file.

Here is a sample `.desktop` file:

```
[Desktop Entry]
Type=Application
Name=Minimal Color Picker
Exec=/usr/local/bin/minimal_colorpicker
Icon=color-picker
NoDisplay=true
StartupNotify=false
X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2
```

- Modify the `Exec=` line so it points to the absolute path of where you put the built executable.
- Save it as `~/.local/share/applications/minimal_colorpicker.desktop`.
- To make KDE aware of the new `.desktop` file, you may need to log out and in again, or run something like `kbuildsycoca6` / `kbuildsycoca5`.

After this, running the program at the path specified by `Exec=` should let you pick colors.
