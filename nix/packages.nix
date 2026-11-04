{ pkgs }:
let
  inherit (pkgs) lib;
  assets = pkgs.runCommand "dotfiles-quickshell-assets" { } ''
    mkdir -p $out/share/dotfiles/quickshell
    cp -R ${
      lib.fileset.toSource {
        root = ../quickshell;
        fileset = lib.fileset.fileFilter (
          file:
          lib.any (suffix: lib.hasSuffix suffix file.name) [
            ".qml"
            ".js"
            ".py"
            ".json"
          ]
        ) ../quickshell;
      }
    }/. $out/share/dotfiles/quickshell/
  '';
  # Commands used by the shell's adapters, not arbitrary installed applications.
  runtime = with pkgs; [
    quickshell
    bash
    coreutils
    systemd
    python3
    bluez
    networkmanager
    brightnessctl
    hyprland
    wvkbd
    darkman
  ];
  shell =
    pkgs.runCommand "dotfiles-quickshell"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        passthru = { inherit assets runtime; };
        meta.mainProgram = "dotfiles-quickshell";
      }
      ''
        mkdir -p $out/bin $out/share
        ln -s ${assets}/share/dotfiles $out/share/dotfiles
        makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/dotfiles-quickshell \
          --prefix PATH : "$out/bin:${lib.makeBinPath runtime}"
        makeWrapper ${pkgs.bash}/bin/bash $out/bin/qs-lock \
          --add-flags ${../quickshell/qs-lock} \
          --prefix PATH : "$out/bin:${lib.makeBinPath runtime}"
        for mode in greeter lock; do
          makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/dotfiles-preview-$mode \
            --add-flags '--path ${assets}/share/dotfiles/quickshell/preview.qml' \
            --set QS_PREVIEW_LOCK "$([ "$mode" = lock ] && echo 1 || echo 0)" \
            --prefix PATH : "$out/bin:${lib.makeBinPath runtime}"
        done
      '';
  greeter =
    pkgs.runCommand "dotfiles-quickshell-greeter"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "dotfiles-greeter";
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/dotfiles-greeter \
          --add-flags '--path ${assets}/share/dotfiles/quickshell/greeter' \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.systemd
              pkgs.coreutils
            ]
          }
      '';
in
{
  inherit assets shell greeter;
  adopt = pkgs.writeShellScriptBin "dotfiles-adopt" ''
    exec ${pkgs.python3}/bin/python3 ${./adopt.py} "$@"
  '';
  default = shell;
}
