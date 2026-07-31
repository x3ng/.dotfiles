# dotfiles

Config files versioned in git, each directory owns its own deployment logic.

## Layout

```
app-name/          # each directory holds one application's configs + install.sh
deploy/
  deploy           # orchestrator
  lib.sh           # shared helpers (dot_link, dot_template, etc.)
  all              # manifest: tui + gui
  tui              # manifest: cli/tui essentials
  gui              # manifest: graphical desktop
```

## Usage

```bash
./deploy/deploy                  # show help
./deploy/deploy -f deploy/all    # install everything
./deploy/deploy -f deploy/tui    # install cli-only
./deploy/deploy -f deploy/gui    # install gui-only
./deploy/deploy vim tmux         # install specific packages

./deploy/deploy --undo -f deploy/tui
./deploy/deploy --undo vim
./deploy/deploy --list            # list deploy/all
./deploy/deploy --dry-run -f deploy/tui
```

## Manifests

Plain text, one package name per line. Support `include <name>` for composition.
Names are resolved relative to the manifest's directory.
Packages are deduplicated (first occurrence wins).

```
# deploy/all
include tui
include gui
```

Use `./deploy/deploy --list` to see the resolved package list.

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
