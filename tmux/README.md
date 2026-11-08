# tmux

Deploy with `./deploy/deploy tmux`. The installer links `tmux.conf` and
`transpose.py` into `~/.config/tmux/`. Python 3 must be on `PATH` for transpose;
the helper supports the V2 JSON layout emitted by the tested tmux 3.8 build.
Ctrl+Tab, Ctrl+comma/period and Ctrl+digits require extended keyboard support.
Kitty's companion configuration explicitly forwards Ctrl+Tab.

## Keys

Press Ctrl+Tab or Ctrl+backslash first. Pressing either prefix again cancels,
without sending it to the application.

| After prefix | Action |
| --- | --- |
| Ctrl+b/f/p/n | Focus left/right/up/down |
| Alt+b/f/p/n | Resize left/right/up/down |
| Ctrl+h/v | Split left/right or top/bottom |
| Ctrl+comma/period | Previous/next window |
| Ctrl+1–9 or 1–9 | Select window |
| Ctrl+w | New window |
| Ctrl+g | Go to session/window/pane; Right expands the tree |
| Alt+g | Move selected pane to the right of the current pane |
| Alt+m | Move selected window into this session |
| Ctrl+r | Toggle zoom |
| Ctrl+e | Open persistent scratch session in a popup |
| Ctrl+y | Emacs copy mode: Ctrl+Space selects, Alt+w copies, Escape exits |
| Ctrl+t | Show pane numbers and swap with the selected pane |
| Alt+h/v | Arrange the entire window side by side / top to bottom |
| Alt+t | Toggle the current pane's direct parent group's split direction |
| Ctrl+o | New session |
| Ctrl+k | Detach |
| Ctrl+x / Alt+w | Close pane / window, with confirmation |
| ? | Show bindings |

Focus, resize and previous/next-window bindings repeat within tmux's
`repeat-time` interval. Other actions require a fresh prefix.

## Local transpose

Alt+t operates on the actual layout tree, not an inferred visual row or column.
The direct parent must contain only ordinary panes; a parent containing nested
groups is rejected. Zoomed/floating targets and insufficient space are rejected.
Other groups and running pane processes are preserved.

The first toggle preserves relative sizes subject to terminal-cell rounding.
Group-specific snapshots in window options let the same key restore exact sizes
on the next toggle. Focus changes do not invalidate them. If the group's geometry
or membership changes, the helper computes a new transpose instead of applying
stale geometry. Independent groups can be toggled separately.

The affected pane numbers are shown after the operation. There is currently no
pre-operation group highlight or status indicator. This helper is not a general
layout editor; automatic layout hooks and concurrent layout writers have not
been comprehensively validated.

## Verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tmux -p 'test_transpose.py'
bash -n tmux/install.sh
./deploy/deploy --dry-run tmux
```
