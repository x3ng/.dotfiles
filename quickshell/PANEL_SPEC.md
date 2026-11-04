# Command panel behavior

The panel is the transient search and status center of a barless desktop.
Current layout and typography are defined in [HOME_SPEC.md](HOME_SPEC.md).

## Search

- Ordinary queries search applications, open windows and registered commands.
- `>` limits commands, `@` limits windows, `/` limits applications. `apps:` remains
  a compatible application prefix. A bare prefix lists its catalog.
- Exact names rank ahead of prefixes, words, substrings and metadata. Every query
  term must match. Window results include application and workspace context.
- Results use 58px two-line rows and retain identity/selection across live updates.
- Disabled actions cannot execute. Search is not file indexing or arbitrary shell
  execution. App/window activation closes the panel; settings commands navigate.

## Interaction

Super+Q opens with input focus. Up/Down and Ctrl+N/P select results; Enter activates;
Shift+Enter preserves terminal launch. Ctrl+1 through Ctrl+0 activate results.
Escape clears a query or returns from details, then closes from home. Tab visits
controls. Outside click and Ctrl+G close. Credential editors retain their own keys.

## Geometry

Maximum width 680px, bounded by screen width minus 32px. Stable top edge near 18%
of screen height; content determines height up to 700px or available height.
Overflow scrolls. Opaque theme surface and 20px corners; no new background blur.

## Persistence and lifecycle

Keep awake stores intent in `$XDG_STATE_HOME/quickshell/keep-awake`, falling back
to `~/.local/state/quickshell/keep-awake`. Restore it before idle timers activate.
Manual sleep, lid policy and authentication remain independent of panel layout.

## Verification boundaries

Live screenshots, scoped search and keyboard navigation were exercised. Earlier
checks covered ranking, multi-term/Chinese matching, disabled commands, stable
selection, workspace layouts and retained delegates during title updates. Both
awake choices survived restart; enabled intent survived hot reload. Current
awake intent remains enabled. UI verification did not invoke power actions,
authenticate, change network connections or test multi-monitor hardware.
