{ pkgs }:
let
  adopt = pkgs.writeShellScriptBin "dotfiles-adopt" ''
    exec ${pkgs.python3}/bin/python3 ${./adopt.py} "$@"
  '';
in
{
  inherit adopt;
  default = adopt;
}
