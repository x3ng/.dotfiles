# Quickshell structure

## Ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| `shell.qml` | Object lifetime, dependency injection, feedback-to-notification wiring | Page state or device operations |
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
| `components/WorkspaceLayoutState.qml` | Per-workspace layout snapshots on native events and explicit refresh | Optimistic layout changes |
| `Notifications.qml` | Live notification actions, bounded popup/history lifetimes, application fallback and local alerts | Device operations |
| `ScreenKeyboard.qml` | Keyboard process, observed visibility and request deadline | Launcher lifecycle |

The native service/compositor remains the source of truth. Views read adapters;
they do not copy device state into their own independent stores. Theme tokens
and reusable controls define the visual language. `components` currently contains
views and runtime helpers.

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

## Route and interaction contract

Status (`overview`) is the only control overview. It is not a gateway to another
settings dashboard. `LauncherPanel.navigate()` validates route IDs and owns all
transitions; ShellActions describes and dispatches actions without implementing
page routing. Search and visible buttons use that same action path.

| View | Entry | Visible responsibility | Destructive actions |
| --- | --- | --- | --- |
| Status | Super+Q, return, status search action | Workspace summary, radio/audio/display/session controls, media | None for unseen notifications |
| Search | Query in Status | Apps, windows, shared commands | Only explicit command results |
| Workspaces | Window icon or search | Workspace/window management | Close requires an inline confirmation |
| Wi-Fi / Bluetooth / audio | Relevant control or search | Devices and connection/device actions | Forget is confirmed next to the selected device |
| Notifications | Bell/count or search | Pending list, history, per-entry actions | Clear belongs above the list it affects |

The footer shows date/time, selected status indicators, notification entry, lock
and tray. It does not duplicate volume/brightness controls or add a settings page.
Tray growth is constrained to a horizontally scrollable strip; it must not push
the date or notification entry outside the panel.

## Presentation and service lifetimes

- Overview/Desktop retain their last plain-data view snapshots while closed and
  refresh on opening. This avoids invisible delegate rebuilds on focus events.
- Details render only their current section. `panelOpen` controls work; an explicit
  `retainContent` allows existing presentation through the exit animation, then
  releases list delegates. Native device objects are not cached across teardown.
- Panel visibility permits readiness probes. Wi-Fi discovery has its own flag and
  runs only in an open Wi-Fi detail page; search/workspaces/notifications do not scan.
- Notification bulk-clear intent survives asynchronous disk loading. Old saved
  records cannot reappear after clearing; genuinely new arrivals remain.
- Timers used for debounce, animation, deadlines and reconnect are not substitutes
  for native state notifications. There is no periodic layout command polling.

## Persistent state

Each module owns its own state file, schema, validation and migration. There is
no global settings document or universal persistence service. Shell-owned state
lives under `$XDG_STATE_HOME/quickshell/`, falling back to
`~/.local/state/quickshell/`:

| File | Owner | Purpose |
| --- | --- | --- |
| `appearance-mode` | AppearanceState | Startup snapshot of the mode owned by darkman |
| `notifications.json` | Notifications | Pending notifications and history |
| `battery-alerts.json` | BatteryAlerts | Charge-cycle alert deduplication |

State writes are atomic and validate stored data. Notifications imports the old
per-shell cache only if its new state file does not exist, and preserves the old
file. Existing empty history is authoritative; a read error must not resurrect
old notifications.

Panel navigation always starts at Overview. Query text, details, expanded menus
and confirmation targets remain transient; navigation has no persisted preference. Device state is owned by the native services, not the navigation.

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

## Deployment

`install.sh` links each root QML module explicitly and links `components/` as a
directory. `quickshell.service` owns the runtime process. The BlueZ pairing helper
is part of runtime and lives in `components/`. Local regression helpers under
ignored `tests/` are neither deployed nor loaded by the shell.

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
device operations. The agent bridge is an isolated text-protocol integration.
