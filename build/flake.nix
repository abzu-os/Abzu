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
      abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};

      # The Source-Built Kernels (Anchored to distribution-macOS tags)
      kernel-leopard = pkgs.callPackage ./derivations/xnu-leopard.nix {};
      kernel-lion = pkgs.callPackage ./derivations/xnu-lion.nix {};
      kernel-mavericks = pkgs.callPackage ./derivations/xnu-mavericks.nix {};
      kernel-tahoe = pkgs.callPackage ./derivations/xnu-tahoe.nix {};

      rootfs = pkgs.runCommand "abzu-minimal-rootfs" {} ''
        mkdir -p $out/{System/Library/Kernels,Library/Preferences,etc,var/tmp}
        echo "Phase 3 Source-Build Test Skeleton" > $out/.abzu-image-kind
      '';

      # Defaulting to Mavericks for the MBP 4,1 active testing.
      # Change to kernel-tahoe for Mac Pro 5,1, or kernel-lion for A1150.
      iso-intel = pkgs.callPackage ./derivations/iso.nix {
        inherit (self.packages.${system}) abzu-init rootfs;
        kernel = self.packages.${system}.kernel-mavericks; 
      };
    };

    defaultPackage.${system} = self.packages.${system}.iso-intel;
  };
}
