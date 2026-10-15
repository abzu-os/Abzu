{
  description = "Abzu Darwin OS - Phase 3 (Source-Built Kernel)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {
      # 1. Our custom init (Universal Binary: i386 + x86_64)
      abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};

      # 2. The Source-Built Kernels (Greatest Hits)
      kernel-lion = pkgs.callPackage ./derivations/xnu-lion.nix {};
      kernel-mavericks = pkgs.callPackage ./derivations/xnu-mavericks.nix {};
      kernel-tahoe = pkgs.callPackage ./derivations/xnu-tahoe.nix {};

      # 3. Minimal Rootfs
      rootfs = pkgs.runCommand "abzu-minimal-rootfs" {} ''
        mkdir -p $out/{System/Library/Kernels,Library/Preferences,etc,var/tmp}
        echo "Phase 3 Source-Build Test Skeleton" > $out/.abzu-image-kind
      '';

      # 4. The ISO generator
      # Defaulting to Mavericks for the MBP 4,1. 
      # Change to `kernel-tahoe` when testing on the Mac Pro 5,1.
      iso-intel = pkgs.callPackage ./derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init rootfs;
        kernel = self.packages.${system}.kernel-mavericks; 
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
