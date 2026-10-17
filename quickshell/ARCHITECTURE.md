# Quickshell structure

## Ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| `shell.qml` | Object lifetime, dependency injection, feedback-to-notification wiring | Page state or device operations |
| `PanelState.qml` | Last main tab and its own persistence lifecycle | Other module state or live navigation |
| `ShellActions.qml` | Searchable command metadata, shared availability, dispatch | System state, asynchronous completion, panel dismissal |
| `DesktopSearch.qml` | Search ranking, stable result identity, activation requests | Navigation or keyboard focus |
| `components/LauncherPanel.qml` | Opening/closing, main tabs, query, selection, focus and shared sizing | Search-result rendering or system commands |
| `components/SearchResultsPage.qml` | Result rendering and scrolling; activation signal | Search ranking, selection ownership or dispatch |
| `DesktopServices.qml` | Audio, brightness, idle inhibition, media/battery adapters, network editor launch | Page navigation |
| `SystemControls.qml` | Network/Bluetooth/power adapters and connection feedback | Search/UI state |
| `HyprlandControls.qml` | Validated, explicit-target workspace/window requests and completion | Page selection or confirmation dialogs |
| `components/WorkspaceLayoutState.qml` | Actual per-workspace layout readback and change signals | Optimistic layout changes |
| `Notifications.qml` | Notification/history state and local notification delivery | Device operations |
| `ScreenKeyboard.qml` | Keyboard process, observed visibility and request deadline | Launcher lifecycle |

The native service/compositor remains the source of truth. Views read adapters;
they do not copy device state into their own independent stores. Theme tokens
and reusable controls define the visual language. `components` currently contains
both views and a few established helpers; file moves should not be confused with
fixing ownership.

## Persistent state

Each module owns its own state file, schema, validation and migration. There is
no global settings document or universal persistence service. Shell-owned state
lives under `$XDG_STATE_HOME/quickshell/`, falling back to
`~/.local/state/quickshell/`:

| File | Owner | Purpose |
| --- | --- | --- |
| `panel-state.json` | PanelState | Last main tab, Desktop or System controls |
| `appearance-mode` | AppearanceState | Startup snapshot of the mode owned by darkman |
| `notifications.json` | Notifications | Pending notifications and history |
| `battery-alerts.json` | BatteryAlerts | Charge-cycle alert deduplication |

New state files should use atomic writes, explicit validation, and protect newer
user changes from late startup reads. PanelState serializes writes and keeps the
latest choice in memory when disk access fails. Notifications imports the old
per-shell cache only if its new state file does not exist, and preserves the old
file. Existing empty history is authoritative; a read error must not resurrect
old notifications.

Only the main tab is remembered for the panel. Query text, detail pages, expanded
menus, confirmation prompts and window/workspace targets are transient. The
opening screen still comes from the current monitor or activated hot corner.
A loaded panel preference is read on opening, so a late disk read cannot move an
already-open panel to another tab. System state such as audio levels, radio state
and workspace layouts stays owned by its native service.

## Action and result contracts

- `ShellActions.available(id)` is the shared predicate for searchable actions and
  matching buttons. The underlying service must still validate a request because
  availability can change between rendering and clicking.
- `ShellActions.execute(id)` returns **request accepted**, not completion or a
  request to close the panel. Parameterized operations such as volume changes,
  choosing a device or targeting a window remain typed service methods.
- Search activation returns `{accepted, closePanel}`. Wayland window activation
  and detached application launch acknowledge dispatch, not completion. This is
  explicit because the Wayland toplevel API does not acknowledge focus requests.
- Hyprland requests have a request ID and completion event carrying operation,
  target and outcome. A page only reacts to its own pending request and clears
  pending UI intentions when it closes. Lock completion acknowledges launching
  the locker; it does not certify that the lock surface has appeared.
- Persistent `error` properties are display state. `feedback(key, summary, body,
  critical)` is the event path for notifications, including repeated identical
  failures. `shell.qml` connects it to the existing notification service.
- Services own processes and external launches. UI components must not construct
  shell commands or Lua snippets. Hyprland command construction lives in
  `components/HyprlandControlCommands.js`, with validation and execution-time
  target lookup.

## UI lifetime rules

Main tabs and stack indices are defined in LauncherPanel. Tab buttons and keyboard
cycling use the same definitions. Search clears back to the selected main tab;
details return to System controls. Deferred focus changes must check that the
panel is still open and still on the relevant page.

Result selection follows identity, not a numerical position after the model
changes. App/action IDs are namespaced; live Wayland windows use object identity.
Changing the query resets selection. Deferred resets carry a revision so a later
explicit keyboard selection wins. Supported detail routes are validated before
changing navigation state. Pages expose `naturalHeight`, while the
launcher owns the shared height ceiling and chrome.

Window action/confirmation state belongs to DesktopPage and is associated with
the expanded window address. Repeater delegates may be rebuilt when a window
changes title or state; they must not own state that needs to survive that update.
Dismissal and target disappearance clear that state. The overview shows every
workspace together; changing the layout picker does not cancel an unrelated
window request. Workspace switching dismisses only after its matching request
succeeds, and model refreshes must not discard that pending completion.

## Adding a feature

1. Add state/validation to the relevant service adapter when needed.
2. For a general searchable command, add metadata and dispatch in ShellActions.
   Reuse `available(id)` in visible buttons. Keep target-specific selection in a
   page, then call the service with that explicit target.
3. Keep navigation and focus changes in LauncherPanel. Render larger independent
   content as a page component, using the existing theme and sizing conventions.
4. Add regression coverage for state transitions, ordering, rejected requests and
   asynchronous completion. Use the runner documented in `tests/README.md`.

Tests use inert adapters or pure Qt offscreen fixtures. They must not open a live
Quickshell PanelWindow, operate real windows, modify network state or lock the
session. New root QML modules also need deployment entries in `install.sh`;
components are deployed through the existing directory symlink.
