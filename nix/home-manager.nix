{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles;
  selected = name: builtins.elem name cfg.profiles;
  source =
    relative:
    if cfg.mode == "development" then
      config.lib.file.mkOutOfStoreSymlink "${cfg.developmentDirectory}/${relative}"
    else
      ../. + "/${relative}";
  hyprFiles = lib.filter (name: lib.hasSuffix ".lua" name) (
    builtins.attrNames (builtins.readDir ../hypr)
  );
  # Link only the static config files, leaving generated monitor rules writable.
  hyprTargets = lib.listToAttrs (
    map (name: {
      name = "hypr/${name}";
      value = "hypr/${name}";
    }) hyprFiles
  );
  targets =
    (lib.optionalAttrs (selected "hyprland") hyprTargets)
    // (lib.optionalAttrs (selected "nullshell") {
      "nullshell/config.json" = "nullshell/config.json";
      "nullshell/wallpaper.json" = "nullshell/wallpaper.json";
    })
    // (lib.optionalAttrs (selected "kitty") {
      "kitty/kitty.conf" = "kitty/kitty.conf";
      "kitty/shaders" = "kitty/shaders";
    })
    // (lib.optionalAttrs (selected "tmux") { "tmux/tmux.conf" = "tmux/tmux.conf"; });
in
{
  options.dotfiles = {
    enable = lib.mkEnableOption "deployment of independently maintained dotfiles";
    profiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "hyprland"
          "nullshell"
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
    xdg.configFile = lib.mapAttrs (_: relative: { source = source relative; }) targets;
  };
}
