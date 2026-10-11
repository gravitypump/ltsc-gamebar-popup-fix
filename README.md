# ltsc-gamebar-popup-fix

Stops this popup from appearing every time you turn on an Xbox controller:

> **We can't open this 'ms-gamebar' link**
> Your device needs a new app to open this link.

Affects Windows 10/11 **LTSC**, **IoT Enterprise**, and debloated installs where Xbox Game Bar
isn't installed. Tested on Windows 11 IoT Enterprise LTSC 2024 (build 26100) with an Xbox One
wireless controller.

## Why it happens

When a controller connects (or you press its Xbox button), Windows tries to open an
`ms-gamebar://` link to launch Game Bar. With Game Bar missing, nothing is registered to handle
that link, so Windows asks you to find an app for it.

## The fix

Register `systray.exe` as the handler for `ms-gamebar`, `ms-gamebarservices` and
`ms-gamingoverlay`. `systray.exe` is a built-in Windows stub that does nothing and exits
immediately, so the link "opens" silently. The fix also turns off the "open Game Bar with the
controller button" and game-capture toggles for your user.

**The handler has to be registered machine-wide (HKLM).** Registering it only for your user
(HKCU), as many guides suggest, did not stop the popup on the tested machine.

## Usage

Pick one.

**Script** (asks for admin, skips any link type that already has a real handler):

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-GameBarPopup.ps1
```

**Registry file:** double-click [`reg/apply.reg`](reg/apply.reg) and accept the prompts.

Then turn the controller off and on. If the popup still shows, sign out and back in.

## Undo

```powershell
powershell -ExecutionPolicy Bypass -File .\Fix-GameBarPopup.ps1 -Undo
```

or double-click [`reg/undo.reg`](reg/undo.reg). The script's undo only removes handlers that
point at `systray.exe`; `undo.reg` removes the keys unconditionally, so don't use it if you've
since installed Game Bar. Neither undo touches the per-user Game Bar toggles.

## If you later install Game Bar

Run the undo first, or Game Bar's own links may be shadowed by the stub.

## Credits

The approach comes from community reports in
[Raphire/Win11Debloat#367](https://github.com/Raphire/Win11Debloat/issues/367) and
[Valkirie/HandheldCompanion#686](https://github.com/Valkirie/HandheldCompanion/issues/686).

## License

[MIT](LICENSE). Free to use, modify and share; just keep the copyright notice.
