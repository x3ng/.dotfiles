# Shared surface material

`Theme.qml` owns the palette and `MaterialSurface.qml` owns the panel finish.
Desktop command panel, OSD, notification banners, tooltips, tray menu, wallpaper
picker, login/lock card and Polkit dialog use this common finish. Embedded controls
and cards retain solid semantic surfaces rather than stacking transparency.

The finish uses a subtle top-to-bottom value change, an outer boundary and an
inner highlight. Text is fully opaque. Desktop surfaces are opaque: the launcher
is a full-screen layer window, so enabling compositor blur there would also blur
its large outside-click backdrop. This implementation does not capture the desktop.

Lock cards sit over the existing blurred wallpaper, with 90% dark / 94% light
coverage. Both input fields use solid input surfaces. Lock appearance follows
the saved desktop appearance mode. Only login cards currently add the efficient
rectangular shadow; narrow layer windows must leave padding before adding shadows.

## Login interaction

Username fields share the same 48px layout and 16px text in greeter and locker.
The lock username is read-only and omitted from mouse/Tab focus. Submit is the
arrow inside the password field; Enter remains available. Session names elide,
errors wrap, and opening the power menu changes the card's natural height.
Preview submit/power actions still exit quietly without authentication or power
operations. Authentication backend behavior is unchanged.

## Preview and deployment

`./preview.sh greeter` and `./preview.sh lock` open ordinary windows. With a
preview running, its private IPC can change mode, palette and feedback:

```sh
quickshell ipc --path ./preview.qml call preview mode true
quickshell ipc --path ./preview.qml call preview light true
quickshell ipc --path ./preview.qml call preview feedback 'Authentication failed' false
quickshell ipc --path ./preview.qml call preview power true
```

These IPC methods exist only in the preview. Greeter deployment includes
`MaterialSurface.qml`; run the existing install-greeter command to update the
system copy. Locker/Polkit have hot reload disabled and must only be restarted
while unlocked / no authorization is active.

## Evidence and references

Checked the live command panel, light/dark lock preview, actual OSD/notification/
Polkit components in a side-by-side fixture, and 420px login/error/session and
power-menu fixtures. Desktop, locker and Polkit loaded successfully afterward;
keep-awake intent and inhibitor stayed enabled. Real login, suspend and power
actions were not used for visual verification.

- Qt MultiEffect source and performance constraints:
  https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html
- Qt RectangularShadow (analytic rectangle shadow rather than general blur):
  https://doc.qt.io/qt-6/qml-qtquick-effects-rectangularshadow.html
- Caelestia's layered colors and compositor-blur coordination:
  https://github.com/caelestia-dots/shell/blob/main/services/Colours.qml

Caelestia informed the separation of palette, layers and blur; this configuration
uses fixed palettes and does not import its dynamic wallpaper analysis or plugins.
