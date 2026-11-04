# Optional Home Manager integration

This repository owns personal configuration, not shell software. Its flake exports
`homeManagerModules.default` and the conservative `adopt` tool. Nullshell is a
separate input with its own packages, NixOS module and Home Manager module.

```nix
dotfiles = {
  enable = true;
  profiles = [ "hyprland" "nullshell" "kitty" "tmux" ];
  mode = "store";
};
```

Store mode deploys the locked input snapshot. Development mode uses explicit live
links to `dotfiles.developmentDirectory` (default `~/.dotfiles`). Nullshell's QML
and Rust implementation do not live here; development of shell code belongs in
that project's checkout. Preferences stay in `nullshell/config.json` and
`nullshell/wallpaper.json`, equally usable without Nix via `deploy/deploy`.

Before Home Manager first adopts unmanaged links, review `nix run .#adopt`, then
use `-- --apply`. The helper archives only verified links owned by this checkout,
refuses foreign/real files and does not change sources. Select matching profiles
with `--profiles`. Already store-managed links are skipped. Backups go under
`$XDG_STATE_HOME/dotfiles/adoption/`.

No service units or system authentication settings are produced by this flake.
The nullshell package owns those. A new session is required when changing shell
implementations; do not remove live QML sources or restart an active locker.
