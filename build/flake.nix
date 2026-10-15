{
  description = "Abzu Darwin OS - Phase 2 (Custom Init Bypass)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {
      abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};

      xnu = pkgs.callPackage ./derivations/xnu.nix {
        kernelFile = /Users/alinamarsfelder/Abzu-kernels/Leopard/mach_kernel;
      };

      rootfs = pkgs.runCommand "abzu-minimal-rootfs" {} ''
        mkdir -p $out/{System/Library/Kernels,Library/Preferences,etc,var/tmp}
        echo "Phase 2 Minimal Test Skeleton" > $out/.abzu-image-kind
      '';

      iso-intel = pkgs.callPackage ./derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init xnu rootfs;
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
