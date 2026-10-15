{
  description = "Abzu Darwin OS - Phase 2 (Custom Init Bypass)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    # We use the NATIVE toolchain for Apple Silicon (aarch64-darwin).
    # This ensures ZERO Rosetta usage. The tools run natively.
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {
      # 1. Our custom init. We tell the NATIVE clang to output x86_64 code.
      # Apple's clang has the x86_64 backend built-in. No Rosetta needed to compile.
      abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};

      # 2. The XNU Kernel. Native perl patches the file. No execution, just byte replacement.
      xnu = pkgs.callPackage ./derivations/xnu.nix {
        kernelFile = /Users/alinamarsfelder/Abzu-kernels/Leopard/mach_kernel;
      };

      # 3. The ISO generator. Native xorriso packs the files.
      iso-intel = pkgs.callPackage ./derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init xnu;
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
