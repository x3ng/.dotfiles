{
  description = "Portable dotfiles with optional Nix packaging and deployment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./nix/packages.nix { inherit pkgs; }
      );
      homeManagerModules.default = import ./nix/home-manager.nix;
      nixosModules.default = import ./nix/nixos.nix;
      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = self.packages.${system}.shell.runtime ++ [
              self.packages.${system}.shell
              pkgs.nixfmt
              pkgs.shellcheck
            ];
          };
        }
      );
      apps = eachSystem (system: {
        default = self.apps.${system}.preview-greeter;
        adopt = {
          type = "app";
          meta.description = "Safely archive legacy dotfiles links before Home Manager adoption";
          program = "${self.packages.${system}.adopt}/bin/dotfiles-adopt";
        };
        preview-greeter = {
          type = "app";
          meta.description = "Preview the greeter without authentication";
          program = "${self.packages.${system}.shell}/bin/dotfiles-preview-greeter";
        };
        preview-lock = {
          type = "app";
          meta.description = "Preview the lock screen without locking the session";
          program = "${self.packages.${system}.shell}/bin/dotfiles-preview-lock";
        };
      });
      checks = eachSystem (system: {
        inherit (self.packages.${system}) shell greeter adopt;
      });
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
