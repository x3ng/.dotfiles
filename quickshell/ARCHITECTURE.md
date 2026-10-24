# Quickshell structure

## Ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| `shell.qml` | Object lifetime, dependency injection, feedback-to-notification wiring | Page state or device operations |
| `PanelState.qml` | Legacy saved-tab file compatibility (not used by navigation) | Other module state or live navigation |
| `ShellActions.qml` | Searchable command metadata, shared availability, dispatch | System state, asynchronous completion, panel dismissal |
| `DesktopSearch.qml` | Search ranking, stable result identity, activation requests | Navigation or keyboard focus |
| `components/LauncherPanel.qml` | Opening/closing, Overview and internal routes, query, selection, focus and shared sizing | Search-result rendering or system commands |
| `components/OverviewPage.qml` | Compact global status and existing action/adapter invocation | Service state or routing |
| `components/SearchResultsPage.qml` | Result rendering and scrolling; activation signal | Search ranking, selection ownership or dispatch |
| `DesktopServices.qml` | Audio, brightness, idle inhibition, media/battery adapters, network editor launch | Page navigation |
| `SystemControls.qml` | Network/Bluetooth/power actions, pairing lifecycle and connection feedback | Search/UI state |
| `components/ConnectivityPane.qml` | Device selection, credential fields and confirmation UI | Commands or copied device state |
| `components/bluetooth_pair.py` | On-demand BlueZ agent bridge; bounded JSON protocol | Device lists, persistent state or status polling |
| `HyprlandControls.qml` | Validated, explicit-target workspace/window requests and completion | Page selection or confirmation dialogs |
| `components/WorkspaceLayoutState.qml` | Actual per-workspace layout readback and change signals | Optimistic layout changes |
| `Notifications.qml` | Live notification actions, bounded popup/history lifetimes, application fallback and local alerts | Device operations |
| `ScreenKeyboard.qml` | Keyboard process, observed visibility and request deadline | Launcher lifecycle |

The native service/compositor remains the source of truth. Views read adapters;
they do not copy device state into their own independent stores. Theme tokens
and reusable controls define the visual language. `components` currently contains
both views and a few established helpers; file moves should not be confused with
fixing ownership.

HyprlandControls publishes plain workspace/window snapshots after the native
event handler returns. WorkspaceSummary consumes these snapshots too. This
avoids synchronously rebuilding nested delegates while Qt is removing a native
workspace object; it does not make the view a separate system-state owner.
WorkspaceSummary further projects these rows to workspace selectors and sorted
window address/app-ID pairs. Focus, title and layout-label changes retain the
existing icon delegates; only structural changes reset its Repeaters.

Launcher and OSD surfaces own both entrance and exit animation in QML. The
matching Hyprland layer rules disable an additional compositor animation for
those two namespaces. Notification banners still use the compositor's exit
fade, since removal currently unmaps their surface immediately.
Theme owns shared motion timings. LauncherPanel keeps layout height separate
from animated frame height and retains the visible route during dismissal.
Service lifecycle still follows `open`, so an exit animation does not prolong
scanning/pairing. Navigation resets on the next opening.
ShellToolTip owns hover-hint presentation across controls, workspace summaries
and the footer/tray. It uses explicit theme colours and an in-scene Qt popup,
so platform tooltip palettes cannot override its surface or text. Theme also
owns its maximum width, hover delay and fade timings; Qt handles the delay
and keeps the popup within the scene bounds.

Notification banners are only a view of the bounded live notification list.
Banner timeout must not close a recorded native notification, or its actions
become invalid. Center records resolve live actions by recordKey; only display
data and the explicit desktop-entry hint are persisted. Sender close, explicit
dismiss and eviction invalidate live actions. Archive fallback is labelled
Open app and must never simulate the original notification's default action.

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

Panel navigation always starts at Overview. The old panel-state file is retained
for compatibility, but LauncherPanel neither reads its route nor writes new tab
choices. Query text, details, expanded menus and confirmation targets remain
transient. Device state is owned by the native services, not the navigation.

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

Routes and stack indices are defined in LauncherPanel. Ordinary Tab traverses
focus. Deleting a search query reveals its source page; Esc and detail return
navigate to Overview, and Esc from Overview dismisses. Reopening always resets
the route. Deferred focus changes must check the panel is still open and not in
a detail editor. Search-result identity and query revision rules are unchanged.
Pages expose `naturalHeight`, while the
launcher owns the content-driven frame height and chrome, constrained by available
screen space. Page content scrolls within that frame.

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
   asynchronous completion. Use the runner documented in
   [tests/quickshell/README.md](../tests/quickshell/README.md).

Tests use inert adapters or pure Qt offscreen fixtures. They must not open a live
Quickshell PanelWindow, operate real windows, modify network state or lock the
session. New root QML modules also need deployment entries in `install.sh`;
components are deployed through the existing directory symlink.

Regression tests, mocks and offscreen previews live in the repository's
`tests/quickshell/` directory. They are run manually and are neither deployed
nor imported by the shell. The Bluetooth pairing helper remains in `components/`
because it provides a runtime feature.

## Connection details

Nearby network/device rows come from native service objects. Selection uses a
stable adapter/name/security or device-address key, so list rebuilding does not
lose the selected editor. Credentials live only in the input field; submit,
selection changes, page close and radio-off clear them. Forget requires a second
click. Views call typed adapter methods and never build commands.

Quickshell 0.3.2 has no BlueZ Agent1 API. SystemControls therefore owns one
short-lived Python helper for a requested pairing, with startup and overall
deadlines. The helper registers BlueZ's KeyboardDisplay agent through
bluetoothctl, selects the requested adapter (its MAC comes from a typed busctl
property), and emits only structured prompts/results. User responses are
validated in both adapter and helper. It does not claim the default-agent role;
leaving the detail page cancels the operation and closes the agent. Native
Quickshell objects remain the source for pairing/connection state and normal
device operations. This is a deliberate, isolated text-protocol exception to
ordinary native service use, with transcript and fake-process regression tests.
