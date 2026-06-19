# dotfiles

Config files versioned in git, deployed to `$HOME` as symlinks.

## Layout

```
app-name/       # each directory holds one application's config files
hosts/<name>    # per-machine filelists mapping source to target
scripts/        # deployment tooling
```

Source paths under each app directory do not mirror `$HOME`. Host files define the mapping.

## hosts/

Plain text, one mapping per line:

```
<src> <dst>
```

`src` relative to repo root, `dst` relative to `$HOME`. Blank lines and `#` comments are ignored.

Host files may include another host file:

```
include base
```

Current host split:

- `base`: shared CLI configuration that is safe on both laptops and servers.
- `laptop`: personal graphical desktop session, including Hyprland, Quickshell, and graphical terminals.
- `server`: server-specific overrides on top of `base`.

## scripts/

`link_all.sh` reads a host file and symlinks each `src` to `$HOME/<dst>`.

```bash
./scripts/link_all.sh hosts/<name>
```

Correct existing links are skipped. Real files at the target are backed up to `<target>.backup.<timestamp>` before being replaced.
