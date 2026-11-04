{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles;
  packages = import ./packages.nix { inherit pkgs; };
  selected = name: builtins.elem name cfg.profiles;
  source =
    relative:
    if cfg.mode == "development" then
      config.lib.file.mkOutOfStoreSymlink "${cfg.developmentDirectory}/${relative}"
    else
      ../. + "/${relative}";
  hyprFiles = lib.filter (name: lib.hasSuffix ".lua" name || name == "hypridle.conf") (
    builtins.attrNames (builtins.readDir ../hypr)
  );
  # Link only the static config files, leaving generated monitor rules writable.
  hyprTargets = lib.listToAttrs (
    map (name: {
      name = "hypr/${name}";
      value = "hypr/${name}";
    }) hyprFiles
  );
  quickshellFiles = lib.filter (name: lib.hasSuffix ".qml" name || lib.hasSuffix ".json" name) (
    builtins.attrNames (builtins.readDir ../quickshell)
  );
  quickshellTargets = lib.listToAttrs (
    map
      (name: {
        name = "quickshell/${name}";
        value = "quickshell/${name}";
      })
      (
        quickshellFiles
        ++ [
          "components"
          "lock"
          "polkit"
          "greeter"
        ]
      )
  );
  targets =
    (lib.optionalAttrs (selected "hyprland") hyprTargets)
    // (lib.optionalAttrs (selected "quickshell") quickshellTargets)
    // (lib.optionalAttrs (selected "kitty") {
      "kitty/kitty.conf" = "kitty/kitty.conf";
      "kitty/shaders" = "kitty/shaders";
    })
    // (lib.optionalAttrs (selected "tmux") { "tmux/tmux.conf" = "tmux/tmux.conf"; });
  unitNames = [
    "quickshell"
    "quickshell-lock"
    "quickshell-polkit"
  ];
  unitText =
    name:
    lib.replaceStrings
      [ "ExecStart=quickshell" "\n[Install]\nWantedBy=graphical-session.target\n" ]
      [ "ExecStart=${packages.shell}/bin/dotfiles-quickshell" "\n" ]
      (builtins.readFile (../quickshell + "/${name}.service"));
in
{
  options.dotfiles = {
    enable = lib.mkEnableOption "deployment of independently maintained dotfiles";
    profiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "hyprland"
          "quickshell"
          "kitty"
          "tmux"
        ]
      );
      default = [ ];
      description = "Explicitly selected configuration groups; other deploy scripts remain independent.";
    };
    mode = lib.mkOption {
      type = lib.types.enum [
        "store"
        "development"
      ];
      default = "store";
      description = "Immutable input snapshot or live links to a local checkout.";
    };
    developmentDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.dotfiles";
      description = "Absolute checkout directory used only for development-mode links.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mode != "development" || lib.hasPrefix "/" cfg.developmentDirectory;
        message = "dotfiles.developmentDirectory must be an absolute path";
      }
    ];
    xdg.configFile =
      lib.mapAttrs (_: relative: { source = source relative; }) targets
      // lib.optionalAttrs (selected "quickshell") (
        lib.listToAttrs (
          map (name: {
            name = "systemd/user/${name}.service";
            value.text = unitText name;
          }) unitNames
        )
      );
    home.packages = lib.optional (selected "quickshell") packages.shell;
    # No WantedBy links: Hyprland startup owns starting this desktop, and its
    # existing Wants= relationships start locker/Polkit. Never restart a locker
    # during activation; a fresh session picks up the new executables safely.
    home.activation.dotfilesUnits = lib.mkIf (selected "quickshell") (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
          run ${pkgs.systemd}/bin/systemctl --user daemon-reload
        fi
      ''
    );
  };
}
