# dotfiles

Config files versioned in git, each directory owns its own deployment logic.

## Layout

```
app-name/          # each directory holds one application's configs + install.sh
deploy/
  deploy           # orchestrator
  lib.sh           # shared helpers (dot_link, dot_template, etc.)
  tui              # CLI and terminal tool profile
  gui              # graphical tool profile
```

## Usage

```bash
./deploy/deploy                  # show help
./deploy/deploy -f deploy/tui    # install CLI and terminal tools
./deploy/deploy -f deploy/gui    # install graphical tools
./deploy/deploy vim tmux         # install specific packages
./deploy/deploy hypr quickshell waybar  # deploy optional desktop configs explicitly

./deploy/deploy --undo -f deploy/tui
./deploy/deploy --undo vim
./deploy/deploy --dry-run -f deploy/tui
```

## Manifests

Plain text, one package name per line. Support `include <name>` for composition.
Names are resolved relative to the manifest's directory.
Packages are deduplicated (first occurrence wins).

```
# deploy/tui
vim
starship
tmux
zellij
yazi
```

## Deployment model

`deploy/deploy` is the orchestrator: it expands profiles, deduplicates
packages, supports dry-runs, and invokes each package. Each package's
`install.sh` is its lifecycle adapter: it owns that package's file targets and
implements `install` and `uninstall`. Keeping those two layers separate lets
simple symlinked packages and interactive/system-level packages use the same
orchestrator.

Desktop-specific configurations remain versioned but are intentionally absent
from the TUI and GUI profiles. Deploy them explicitly when that desktop is in
use.

## install.sh convention

Each `install.sh` accepts `install` or `uninstall`:

```bash
./vim/install.sh install
./vim/install.sh uninstall
```

Most packages symlink files into place. Packages may copy generated or
declarative files instead when the target application writes runtime fields back
to the same file. Runtime state, caches, logs, auth files, sessions, and
installed package directories stay outside dotfiles.

Interactive packages refuse batch execution and guide the user:

```bash
./deploy/deploy mihomo                          # prompts for SUB_URL
sudo MIHOMO_SUB_URL=<url> ./deploy/deploy mihomo
sudo XREMAP_SKIP_REVIEW=1 ./deploy/deploy xremap
TMUX_PREFIX=C-a ./deploy/deploy tmux             # server prefix override
```
