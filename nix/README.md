# Optional Nix integration

Native configuration files and `deploy/` scripts remain usable without Nix.
This adapter packages Quickshell and deploys selected configs; QML, Lua and
application preferences stay in their original files.

## Interface

- `packages.<system>.shell`: runtime wrapper, lock helper and safe previews.
- `packages.<system>.greeter`: independent greetd entry point using store QML.
- `homeManagerModules.default`: Hyprland, Quickshell, Kitty and tmux profiles.
- `nixosModules.default`: PAM/Polkit/UPower integration and optional greetd setup.
- `nix develop`: runtime dependencies for source development and previews.
- `nix run .#preview-greeter` / `.#preview-lock`: packaged previews, no authentication.
- `nix run .#adopt`: inspect legacy links before Home Manager adoption.

```nix
inputs.dotfiles.url = "github:x3ng/.dotfiles";
inputs.dotfiles.inputs.nixpkgs.follows = "nixpkgs";
```

Import `inputs.dotfiles.nixosModules.default` and enable:

```nix
programs.dotfilesShell = {
  enable = true;
  greeter.enable = true;
};
```

The host still owns compositor choice, portals, networking, audio, fonts, lid
policy and Darkman. Do not enable the greeter alongside GDM or another display
manager. Modules use the consumer's `pkgs`, including overlays.

Import `inputs.dotfiles.homeManagerModules.default` and select:

```nix
dotfiles = {
  enable = true;
  profiles = [ "hyprland" "quickshell" "kitty" "tmux" ];
  mode = "store";
};
```

Store mode deploys the locked input snapshot. For live configuration links:

```nix
dotfiles.mode = "development";
dotfiles.developmentDirectory = "${config.home.homeDirectory}/.dotfiles";
```

Development mode does not change packaged dependencies or the system greeter.
For source previews run `nix develop`, then `./quickshell/preview.sh greeter` or
`./quickshell/preview.sh lock`. Runtime state remains in XDG state/cache paths.

## First adoption

Build both host and home outputs first. Review `nix run .#adopt`, run it with
`-- --apply`, then immediately apply Home Manager. The helper archives only exact
legacy links to `$XDG_STATE_HOME/dotfiles/adoption/<timestamp>/` (normally under
`~/.local/state`). Unrelated entries are preserved; ownership conflicts abort
before any change. Backups retain the absolute target hierarchy for restoration.
The helper defaults to all four profiles. For partial adoption, pass e.g.
`--profiles kitty tmux` to match the selected Home Manager profiles.

Do not run `deploy` for the same profiles afterward. The generic installer refuses
to replace store-managed links; other profiles can keep using their scripts.
The three user units are generated from the portable templates, replacing the
runtime executable and removing global enablement. Activation reloads units but
never restarts a locker or agent. Hyprland starts the desktop and its dependencies.
Use a fresh login after migration rather than restarting authentication processes.

NixOS greeter QML comes directly from the package, without a copy in `/etc` or
access to a user home. Non-Nix installation retains `install-greeter`.

## Versioning

Commit dotfiles first, then update the consumer's dotfiles input. An unpublished
local integration can pin `git+file:///absolute/checkout`; that is a local-only
transport. After publishing the commit, change to the GitHub URL above and update
the lock node. No submodule or second version pointer is needed.

`--override-input dotfiles path:/absolute/checkout` builds uncommitted local edits,
but still copies them to the store. Development mode/source previews provide
hot reload. No push or system activation is performed by the flake itself.
