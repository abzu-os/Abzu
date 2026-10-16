{
  description = "Abzu Darwin OS - Phase 3/5 (rootfs + ISO pipeline, Linux-tolerant)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systemsLinux  = [ "x86_64-linux" "aarch64-linux" ];
      systemsDarwin = [ "x86_64-darwin" "aarch64-darwin" ];

      manifests = {
        homelab          = ../packages/homelab/manifest.json;
        gaming           = ../packages/gaming/manifest.json;
        history-archives = ../packages/history-archives/manifest.json;
      };
      quiverDefaults =
        if builtins.pathExists ../packages/gaming/quiver-defaults.json
        then ../packages/gaming/quiver-defaults.json
        else null;

      mkRefind = pkgs: pkgs.callPackage ./derivations/refind.nix {};

      mkComponents = pkgs:
        let
          stubs = pkgs.callPackage ./derivations/stubs.nix {};
          openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
            srcInfo    = { openbsdSnap = "76-current"; };
            manifest   = ../userland/import/tools.manifest;
            skipList   = ../userland/import/skip.txt;
            compatSrc  = ../userland/mach_compat/abzu-compat.c;
            etcOverlay = ../userland/etc;
          };
          cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix {};
          gui-core = pkgs.callPackage ./derivations/gnustep.nix {
            src       = ../gui;
            themeDir  = ../gui/themes/abzu-aqua;
            shellMenu = ../gui/AbzuShell/shell-menu.json;
          };
          packages-shelf = pkgs.callPackage ./derivations/packages.nix {
            inherit manifests quiverDefaults;
          };
        in stubs // {
          inherit openbsd-userland cuneiform-input gui-core packages-shelf;
        };

      mkLinuxSet = pkgs:
        let
          c = mkComponents pkgs;
          xnu-kernel = c.efistub;
          rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
            kernel           = xnu-kernel;
            userland         = c.openbsd-userland;
            gui              = c.gui-core;
            packages         = c.packages-shelf;
            python3          = pkgs.python3;
            cuneiform-input  = c.cuneiform-input;
            efistub          = c.efistub;
            phase5-configs   = c.phase5-configs;
            packages-shelf   = c.packages-shelf;
          };
          rootfs-slim = pkgs.callPackage ./derivations/rootfs-slim.nix {
            xnu-kernel       = xnu-kernel;
            openbsd-userland = c.openbsd-userland;
            gui-core         = c.gui-core;
            cuneiform-input  = c.cuneiform-input;
            packages-shelf   = c.packages-shelf;
            phase5-configs   = c.phase5-configs;
          };
          kernel-marker = pkgs.runCommand "abzu-mach-kernel-marker" {} ''
            mkdir -p $out
            echo 'PLACEHOLDER mach_kernel - XNU requires an Apple SDK; use packages.x86_64-darwin.kernel-mavericks or `make kernel ABZU_KERNEL_PATH=<Catalina mach_kernel>` in build/' > $out/mach_kernel
          '';
          abzu-init-x86 = pkgs.runCommand "abzu-init-x86_64" {} ''
            mkdir -p $out/sbin
            gcc -m64 -nostdlib -static -e _main -O2 \
                -o $out/sbin/abzu ${./derivations/abzu-init.c}
          '';
        in {
          rootfs-intel-cross = rootfs-intel;
          refind             = mkRefind pkgs;
          iso-intel          = pkgs.callPackage ./derivations/iso.nix {
            rootfs    = rootfs-intel;
            kernel    = kernel-marker;
            abzu-init = abzu-init-x86;
            xorriso   = pkgs.xorriso;
            mtools    = pkgs.mtools;
            dosfstools= pkgs.dosfstools;
            efiPayload= mkRefind pkgs;
          };
          rootfs             = rootfs-slim;
          rootfs-slim        = rootfs-slim;
          abzu-init          = abzu-init-x86;
          openbsd-userland   = c.openbsd-userland;
          gui-core           = c.gui-core;
          cuneiform-input    = c.cuneiform-input;
          packages-shelf     = c.packages-shelf;
          efistub            = c.efistub;
          phase5-configs     = c.phase5-configs;
        };

      mkDarwinSet = pkgs:
        let
          c = mkComponents pkgs;
          
          # The Source-Built Kernels
          kernel-leopard   = pkgs.callPackage ./derivations/xnu-leopard.nix {};
          kernel-lion      = pkgs.callPackage ./derivations/xnu-lion.nix {};
          kernel-mavericks = pkgs.callPackage ./derivations/xnu-mavericks.nix {};
          kernel-tahoe     = pkgs.callPackage ./derivations/xnu-tahoe.nix {};
          
          # Track 1: Abzu Userspace & Theming
          abzu-init-darwin = pkgs.callPackage ./derivations/abzu-init.nix {};
          abzu-wallpapers  = pkgs.callPackage ./derivations/abzu-wallpapers.nix {};
          abzu-rootfs      = pkgs.callPackage ./derivations/abzu-gnustep-rootfs.nix {
            abzu-init = abzu-init-darwin;
            inherit abzu-wallpapers;
          };

          rootfs-intel = pkgs.callPackage ./derivations/rootfs.nix {
            kernel           = kernel-mavericks;
            userland         = c.openbsd-userland;
            gui              = c.gui-core;
            packages         = c.packages-shelf;
            python3          = pkgs.python3;
            cuneiform-input  = c.cuneiform-input;
            efistub          = c.efistub;
            phase5-configs   = c.phase5-configs;
            packages-shelf   = c.packages-shelf;
          };
          rootfs-slim = pkgs.callPackage ./derivations/rootfs-slim.nix {
            xnu-kernel       = kernel-mavericks;
            openbsd-userland = c.openbsd-userland;
            gui-core         = c.gui-core;
            cuneiform-input  = c.cuneiform-input;
            packages-shelf   = c.packages-shelf;
            phase5-configs   = c.phase5-configs;
          };
        in {
          # Expose Track 1 components
          inherit abzu-wallpapers abzu-rootfs;
          
          abzu-init        = abzu-init-darwin;
          inherit kernel-leopard kernel-lion kernel-mavericks kernel-tahoe;
          inherit rootfs-intel rootfs-slim;
          rootfs           = rootfs-slim;
          openbsd-userland = c.openbsd-userland;
          gui-core         = c.gui-core;
          cuneiform-input  = c.cuneiform-input;
          packages-shelf   = c.packages-shelf;
          efistub          = c.efistub;
          phase5-configs   = c.phase5-configs;
          
          iso-intel = pkgs.callPackage ./derivations/iso.nix {
            rootfs    = rootfs-intel;
            kernel    = kernel-mavericks;
            abzu-init = abzu-init-darwin;
            xorriso   = pkgs.xorriso;
            mtools    = pkgs.mtools;
            dosfstools= pkgs.dosfstools;
            efiPayload= mkRefind pkgs;
          };
        };

      allSets = builtins.listToAttrs (
        map (s: { name = s; value = mkLinuxSet  (import nixpkgs { system = s; }); }) systemsLinux ++
        map (s: { name = s; value = mkDarwinSet (import nixpkgs { system = s; }); }) systemsDarwin
      );
    in {
      packages = allSets;

      defaultPackage = builtins.mapAttrs (_: set: set.iso-intel) allSets;

      checks = builtins.mapAttrs (_: set: {
        shelf-manifests = set.packages-shelf;
      }) allSets;
    };
}
