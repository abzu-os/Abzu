{
  description = "Abzu Darwin OS - Phase 3/5 (rootfs + ISO pipeline, Linux-tolerant)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systemsLinux  = [ "x86_64-linux" "aarch64-linux" ];
      systemsDarwin = [ "x86_64-darwin" "aarch64-darwin" ];

      # ------------------------------------------------------------------
      # AUDIT FIX (2026-10-15, A1): the previous flake defined ONLY
      # aarch64-darwin, so CI's `nix eval ./build#packages.x86_64-linux.rootfs-intel-cross`
      # and `nix flake check` failed outright, and rootfs.nix / rootfs-slim.nix
      # could not even be callPackage'd because their arguments
      # (efistub, phase5-configs, packages-shelf, srcInfo, themeDir, shellMenu,
      # manifests...) had no backing attributes anywhere. This rewrite wires
      # every consumer argument on both Linux (eval/build of the installer
      # skeleton + ISO dry-run) and Darwin (real XNU kernel builds).
      # Placeholder payloads live in derivations/stubs.nix — search "PLACEHOLDER".
      # ------------------------------------------------------------------

      repoRoot = ../.;
      manifests = [
        ../packages/homelab/manifest.json
        ../packages/gaming/manifest.json
        ../packages/history-archives/manifest.json
      ];

      # rEFInd prebuilt EFI binaries (BOOTX64.EFI/BOOTIA32.EFI). This is the
      # real El Torito boot payload for the ISO — fixes B4/A1: previously no
      # flake attribute produced an ESP, so every ISO was unbootable-by-design.
      mkRefind = pkgs: pkgs.callPackage ./derivations/refind.nix {};

      # Component plumbing shared by both host families; only the kernel
      # payload differs (XNU cannot build on Linux — needs an Apple SDK).
      mkComponents = pkgs:
        let
          stubs = pkgs.callPackage ./derivations/stubs.nix {};
          openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
            srcInfo    = { openbsdSnap = "76-current"; };
            manifest   = ../userland/import/tools.manifest;
            skipList   = ../userland/import/skip.txt;
            compatSrc  = ../userland/mach_compat/abzu-compat.c;
            etcOverlay = ../userland/etc;
            inherit repoRoot;
          };
          cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix {};
          gui-core = pkgs.callPackage ./derivations/gnustep.nix {
            src       = ../gui;
            themeDir  = ../gui/themes/abzu-aqua;
            shellMenu = ../gui/AbzuShell/shell-menu.json;
            inherit repoRoot;
          };
          packages-shelf = pkgs.callPackage ./derivations/packages.nix {
            inherit manifests;
          };
        in stubs // {
          inherit openbsd-userland cuneiform-input gui-core packages-shelf;
        };

      mkLinuxSet = pkgs:
        let
          c = mkComponents pkgs;
          # No XNU on Linux: consumers guard on /System presence and fall back
          # to "installer-skeleton" mode (see rootfs*.nix LINUX TOLERANCE notes).
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
            inherit repoRoot;
          };
          rootfs-slim = pkgs.callPackage ./derivations/rootfs-slim.nix {
            xnu-kernel       = xnu-kernel;
            openbsd-userland = c.openbsd-userland;
            gui-core         = c.gui-core;
            cuneiform-input  = c.cuneiform-input;
            packages-shelf   = c.packages-shelf;
            phase5-configs   = c.phase5-configs;
          };
          # iso.nix demands ${kernel}/mach_kernel. On Linux that file can only
          # be a marker; the resulting ISO is explicitly NON-BOOTABLE (dry-run
          # artifact validating the packaging chain). Real kernels come from
          # packages.<darwin>.kernel-* or build/Makefile ABZU_KERNEL_PATH.
          kernel-marker = pkgs.runCommand "abzu-mach-kernel-marker" {} ''
            mkdir -p $out
            echo 'PLACEHOLDER mach_kernel - XNU requires an Apple SDK; use packages.x86_64-darwin.kernel-mavericks or `make kernel ABZU_KERNEL_PATH=<Catalina mach_kernel>` in build/' > $out/mach_kernel
          '';
          abzu-init-x86 = pkgs.runCommand "abzu-init-x86_64" {} ''
            mkdir -p $out/sbin
            # Same freestanding init as abzu-init.nix, ELF instead of Mach-O:
            # i386+x86_64 Darwin slices are impossible on a Linux host.
            gcc -m64 -nostdlib -static -e _main -O2 \
                -o $out/sbin/abzu ${./derivations/abzu-init.c}
          '';
        in {
          # ---- CI targets referenced by .github/workflows/build-iso.yml ----
          rootfs-intel-cross = rootfs-intel;
          refind             = mkRefind pkgs;
          iso-intel          = pkgs.callPackage ./derivations/iso.nix {
            rootfs    = rootfs-intel;
            kernel    = kernel-marker;
            abzu-init = abzu-init-x86;
            xorriso   = pkgs.xorriso;
            # AUDIT FIX (2026-10-15): iso.nix's ESP recipe shells out to
            # mkfs.vfat / mmd / mcopy when efiPayload is set. callPackage
            # would otherwise default those optional args to null and the
            # build would die at `mkfs.vfat: command not found`.
            mtools     = pkgs.mtools;
            dosfstools = pkgs.dosfstools;
            # Real EFI boot binaries land on the ESP; XNU chainload still
            # needs a genuine mach_kernel/boot.efi (Darwin set or Makefile).
            efiPayload = mkRefind pkgs;
          };
          # ---- components (also handy for `nix build ./build#...`) ----
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
          # The Source-Built Kernels (anchored to distribution-macOS tags).
          # NOTE: secondary fetchzip pins (Libc/AvailabilityVersions/
          # bootstrap_cmds) carry sha256-AAAA... placeholders — refresh with
          #   nix-prefetch-url --unpack <url>
          # (scripts/update-src-hashes.sh TODO: extend to xnu-*.nix pins).
          kernel-leopard   = pkgs.callPackage ./derivations/xnu-leopard.nix {};
          kernel-lion      = pkgs.callPackage ./derivations/xnu-lion.nix {};
          kernel-mavericks = pkgs.callPackage ./derivations/xnu-mavericks.nix {};
          kernel-tahoe     = pkgs.callPackage ./derivations/xnu-tahoe.nix {};
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
            inherit repoRoot;
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
          abzu-init        = pkgs.callPackage ./derivations/abzu-init.nix {};
          inherit kernel-leopard kernel-lion kernel-mavericks kernel-tahoe;
          inherit rootfs-intel rootfs-slim;
          rootfs           = rootfs-slim;
          openbsd-userland = c.openbsd-userland;
          gui-core         = c.gui-core;
          cuneiform-input  = c.cuneiform-input;
          packages-shelf   = c.packages-shelf;
          efistub          = c.efistub;
          phase5-configs   = c.phase5-configs;
          # Defaulting to Mavericks for the MBP 4,1 active testing.
          # Change kernel here to kernel-tahoe for Mac Pro 5,1, or
          # kernel-lion for A1150 machines.
          iso-intel = pkgs.callPackage ./derivations/iso.nix {
            rootfs    = rootfs-intel;
            kernel    = kernel-mavericks;
            abzu-init = pkgs.callPackage ./derivations/abzu-init.nix {};
            xorriso   = pkgs.xorriso;
            # See Linux-set note: ESP staging needs mtools + dosfstools.
            mtools     = pkgs.mtools;
            dosfstools = pkgs.dosfstools;
            efiPayload = mkRefind pkgs;
          };
        };

      allSets = builtins.listToAttrs (
        map (s: { name = s; value = mkLinuxSet  (import nixpkgs { system = s; }); }) systemsLinux ++
        map (s: { name = s; value = mkDarwinSet (import nixpkgs { system = s; }); }) systemsDarwin
      );
    in {
      packages = allSets;

      # Backwards-compatible alias for the pre-flake-era `defaultPackage` spell.
      defaultPackage = builtins.mapAttrs (_: set: set.iso-intel) allSets;

      # `nix flake check`: the shelf derivation itself runs the same
      # provenance/parse gate as scripts/verify-packages.sh, so building it
      # per-system is the meaningful check we can perform without an Apple SDK.
      checks = builtins.mapAttrs (_: set: {
        shelf-manifests = set.packages-shelf;
      }) allSets;
    };
}
