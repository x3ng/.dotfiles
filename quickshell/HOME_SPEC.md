# Command panel home layout

This is a transient, keyboard-first command panel for a barless desktop.
Opening it focuses search immediately. Do not apply persistent-taskbar patterns
such as tiny selected-state underlines to its controls.

## Header

The 44px header has two states. Empty input shows time, date/weekday and battery
on the left, with clickable `@ Windows`, `> Commands`, `/ Applications` hints on
the right. Time and percentage use 18px demibold primary text; date uses 15px
demibold secondary text. Full date and battery details are available on hover.
Below 600px, shorten the date and show only prefix symbols in the hints.

Typing or IME preedit hides status and hints, giving the entire row to the query.
Clearing restores them. Input focus remains available in both states; there is
no additional click to begin searching and no placeholder competing with status.

## Body

1. Workspaces own a full 44px row: number, up to three application icons, then
   an overflow count. Scroll horizontally on overflow. Management has its own
   button. Never share this row with notification content.
2. Wi-Fi and Bluetooth use equal columns, 44px rows and 16px primary text.
   Long values elide, with full detail in tooltips.
3. Volume and brightness use equal outer columns and 6px slider tracks. Speaker
   mute and audio-device selection are distinct actions. Brightness has no dummy
   device-button slot; its slider uses the available width.
4. Latest notification uses a separate 40px single-line preview, bell, count and
   center entry. Full summary and application are in the tooltip.
5. Media controls appear only when a player exists.

## Footer

Center a content-sized group of theme, awake, lock and tray controls. Utility
buttons have 36px targets and 20px icons with 2px rounded strokes. Awake uses a
coffee icon and selected surface; its tooltip reports state and click action.
No long Keep awake label, eye icon, separate switch or underline. Tray logos
remain the applications' original assets; overflow is horizontally scrollable.

## Detail pages and live data

Compact 32px headers combine back/title with relevant page actions. Workspace
cards stack vertically; windows inside each card flow horizontally and wrap,
with content-sized widths capped to the row. Preserve delegate identity and
window-card widths across title changes so hover does not flicker.

## Verification

Live home, query and cleared-query screenshots were checked. `/ kitty` returns
only the application; Ctrl+U restores header status. Full desktop hot reload
succeeds. Earlier 420px fixtures covered footer, media and long labels; those
fixtures predate the current dual-state header and are not proof of its rendering.
