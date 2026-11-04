{
  description = "Portable personal configuration with optional Home Manager deployment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = eachSystem (
        system: import ./nix/packages.nix { pkgs = nixpkgs.legacyPackages.${system}; }
      );
      homeManagerModules.default = import ./nix/home-manager.nix;
      apps = eachSystem (system: {
        adopt = {
          type = "app";
          program = "${self.packages.${system}.adopt}/bin/dotfiles-adopt";
        };
      });
      checks = eachSystem (system: {
        inherit (self.packages.${system}) adopt;
      });
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
