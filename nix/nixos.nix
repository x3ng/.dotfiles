{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dotfilesShell;
  packages = import ./packages.nix { inherit pkgs; };
in
{
  options.programs.dotfilesShell = {
    enable = lib.mkEnableOption "system integration for the dotfiles Quickshell desktop";
    greeter.enable = lib.mkEnableOption "the independently packaged greetd interface";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.pam.services.quickshell-lock = { };
      security.polkit.enable = true;
      services.upower.enable = true;
    })
    (lib.mkIf cfg.greeter.enable {
      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "greeter";
          command = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.cage}/bin/cage -s -d -- ${packages.greeter}/bin/dotfiles-greeter";
        };
      };
    })
  ];
}
