# Quickshell regression checks

From the repository root:

```sh
bash quickshell/tests/run.sh
```

The runner uses `node --test` for JavaScript and extracted production QML action
handlers, then runs the desktop and search-navigation Python runners for offscreen
Qt interaction checks, including real Tab/Backtab and Ctrl+N/P delivery. No test connects/disconnects real network devices,
changes compositor windows, or launches a desktop preview.

Use the installed Node, Python and Qt Test runner first. The Python runner can
locate `qmltestrunner` in the installed Quickshell Nix closure; alternatively set
`QMLTESTRUNNER`. If tools are unavailable:

```sh
nix shell nixpkgs#nodejs nixpkgs#python3 nixpkgs#qt6.qtdeclarative -c bash quickshell/tests/run.sh
```

The command-generation test also executes 27 Lua dispatcher simulations when
`texlua` or `lua` is installed (or `LUA` names an interpreter). Otherwise it
reports that this optional execution stage was skipped; JS input validation
still runs. The Lua environment is mocked and cannot reach Hyprland.

Coverage includes:

- Wi-Fi failed-switch recovery on the same device, isolation across adapters,
  intentional disconnect, suppression expiry, timeout, native-failure dedup,
  connection loss debounce, and Bluetooth request outcomes.
- Explicit window/workspace targets, command input validation, disappeared
  targets, empty numbered workspaces, and dispatcher rejection.
- Correlated desktop operation results, startup failure without an `exited`
  signal, timeouts, and stale process callbacks after a new request.
- Power service property parsing, startup failure and accepted/rejected actions.
- Shared actions, search navigation, service controls and desktop UI behavior.
- Deferred selection resets, invalid detail routes, closed-panel focus guards,
  narrow button/confirmation layouts, and cancellation of stale UI intentions.
- Rejected radio/disconnect requests that emit no native state signal: the
  suppression deadline must still run and restore later loss notifications.
- Panel-owned main-tab persistence, late-load precedence, serialized writes,
  invalid state preservation, and reopening without restoring transient search.
- Notification history migration, authoritative empty history, live-event merges,
  invalid state preservation, and persistence failure handling.
- Battery alert charge-cycle deduplication, critical escalation, and preservation
  of invalid, unsupported or unreadable state files.
- Workspace overview at narrow and wide widths, independent column stacking,
  compact windows and shared title/layout headers, contextual layout controls,
  right-click window actions, and correlated workspace-switch completion.

The lifecycle tests simulate Process events and timers; they do not prove
compositor integration or D-Bus method behavior. Keep real-session checks
read-only unless a user explicitly requests a window or hardware action.

Power service availability is probed at shell startup and panel opening using
its D-Bus `ActiveProfile` property, because Quickshell 0.3.2 has no native
availability property. A service started/stopped while the panel remains open
is reflected on the next opening; no permanent watcher or polling is added.

To capture the overview with mock windows, entirely offscreen:

```sh
DESKTOP_SCREENSHOT=/tmp/quickshell-overview.png python3 -B quickshell/tests/test_desktop_ui.py
```

The capture uses the real page components with a dark test theme and placeholder
application icons. It does not open or capture the live desktop.
