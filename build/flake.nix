{
  description = "Abzu Darwin OS - Phase 2 (Custom Init Bypass)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    # Native M4 toolchain (Zero Rosetta)
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {
      # 1. Our custom init (Universal Binary: i386 + x86_64)
      abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};

      # 2. The XNU Kernel (Leopard 10.5.8)
      xnu = pkgs.callPackage ./derivations/xnu.nix {
        kernelFile = /Users/alinamarsfelder/Abzu-kernels/Leopard/mach_kernel;
      };

      # 3. MINIMAL ROOTFS FOR PHASE 2 TEST
      # This provides a bare skeleton to satisfy iso.nix without pulling in 
      # the massive Phase 5 dependencies (openbsd-userland, gui, etc.).
      # Once Phase 2 is proven, we will swap this out for rootfs-slim.nix!
      rootfs = pkgs.runCommand "abzu-minimal-rootfs" {} ''
        mkdir -p $out/{System/Library/Kernels,Library/Preferences,etc,var/tmp}
        echo "Phase 2 Minimal Test Skeleton" > $out/.abzu-image-kind
      '';

      # 4. The ISO generator
      iso-intel = pkgs.callPackage ./derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init xnu rootfs;
        # Provide rEFInd from nixpkgs
        refind = pkgs.refind; 
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
