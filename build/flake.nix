{
  description = "Abzu Darwin OS - Phase 2 (Custom Init Bypass)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {
      # 1. Our custom, statically-linked init program
      abzu-init = pkgs.callPackage ./build/derivations/abzu-init.nix {};

      # 2. The XNU Kernel (Patched to look for /sbin/abzu instead of launchd)
      # We pass the pre-compiled kernel file
      xnu = pkgs.callPackage ./build/derivations/xnu.nix {
        kernelFile = /Users/alinamarsfelder/Abzu-kernels/Leopard/mach_kernel;
      };

      # 3. The ISO generator (Leopard Architecture)
      iso-intel = pkgs.callPackage ./build/derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init xnu;
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
