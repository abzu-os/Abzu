{
  description = "Abzu — Darwin kernel + OpenBSD userland + GNUstep 'Aqua' desktop ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    darwin-nix = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gnustep-src = {
      url = "github:gnustep/libs-base/master";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , darwin-nix
    , gnustep-src
    }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
      forAll = f: builtins.foldl' (r: s: r // f s) { } systems;

      kernelPatches = [
        ../kernel/patches/0001-abzu-identify-build-version.patch
        ../kernel/patches/0002-openbsd-wx-enforcement.patch
      ];

      srcInfo = {
        xnuRepo = "https://github.com/apple-oss-distributions/xnu.git";
        xnuTag = "xnu-4903.278.28";
        xnuRev = "xnu-4903.278.28";
        xnuSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        openbsdSnap = "auto(7.9)";
      };

      mkPkgsFor = s:
        let native = nixpkgs.legacyPackages.${s}; in {
          inherit native;
          crossIntel   = native.pkgsCross.x86_64-darwin;
          crossArm64   = native.pkgsCross.aarch64-darwin;
          crossRiscv64 = native.pkgsCross.riscv64-linux;
          crossPowerPC = native.pkgsCross.powerpc64le-linux;
          crossLoong64 = native.pkgsCross.loongarch64-linux;
          crossSparc64 = native.pkgsCross.sparc64-linux;
        };

      mkPkg = pkgs: pkgsSystem: rec {
        inherit pkgs;

        xnu-kernel = pkgs.callPackage ./derivations/xnu.nix {
          inherit srcInfo;
          xnu-sources = pkgs.callPackage ./derivations/xnu-sources.nix { inherit srcInfo; };
          patches = kernelPatches;
          cctools = pkgs.cctools;
          clang = pkgs.clang;
          llvm = pkgs.llvm;
          precompiled = false; 
        };

        xnu-kernel-precompiled = pkgs.callPackage ./derivations/xnu.nix {
          inherit srcInfo;
          precompiled = true;
          kernelPath = /Users/alinamarsfelder/Abzu-Kernels/kernel;
        };

        openbsd-userland = pkgs.callPackage ./derivations/openbsd-userland.nix {
          inherit srcInfo;
          manifest = ../userland/import/tools.manifest;
          skipList = ../userland/import/skip.txt;
          compatSrc = ../userland/mach_compat/abzu-compat.c;
          etcOverlay = ../userland/etc;
          repoRoot = ../.;
        };

        gui-core = pkgs.callPackage ./derivations/gnustep.nix {
          src = gnustep-src;
          themeDir = ../gui/themes/abzu-aqua;
          shellMenu = ../gui/gworkspace-shell/shell-menu.json;
          repoRoot = ../.;
        };

        abzu-packages = pkgs.callPackage ./derivations/packages.nix {
          manifests = [
            ../packages/gaming/manifest.json
            ../packages/history-archives/manifest.json
            ../packages/homelab/manifest.json
          ];
        };

        cuneiform-input = pkgs.callPackage ./derivations/cuneiform-input.nix { };

        phase5-configs = pkgs.runCommand "abzu-phase5-configs" { } ''
          mkdir -p $out
          cp -r --no-preserve=ownership ${../packages/homelab/etc-skel} $out/etc-skel
          cp -r --no-preserve=ownership ${../packages/history-archives/stellarium-defaults} $out/stellarium-defaults
        '';

        packages-shelf = ../packages;

        rootfs-intel = 
          let rootfsFn = import ./derivations/rootfs.nix;
          in rootfsFn {
            lib = pkgs.lib;
            stdenvNoCC = pkgs.stdenvNoCC;
            runCommand = pkgs.runCommand;
            python3 = pkgs.python3;
            kernel = xnu-kernel;
            userland = openbsd-userland;
            gui = gui-core;
            packages = abzu-packages;
            cuneiform-input = cuneiform-input;
            efistub = pkgs.callPackage ./derivations/refind.nix { };
            inherit phase5-configs packages-shelf;
          };

        rootfs-phase5 = pkgs.callPackage ./derivations/rootfs-slim.nix {
          inherit xnu-kernel openbsd-userland gui-core cuneiform-input
                  phase5-configs packages-shelf;
        };

        iso-intel = pkgs.callPackage ./derivations/iso.nix {
          rootfs = rootfs-intel;
          refind = pkgs.callPackage ./derivations/refind.nix { };
          volumeLabel = "ABZU_ROOTFS";
          # ONLY nullify the strictly Linux-only tool. Keep mtools and dosfstools!
          hfsprogs = null;
        };

        xnu-kernel-release = xnu-kernel;
        gui-theme = gui-core.passthru.themeBundle or gui-core;
      };

      mkCrossIntelRootfs = pkgsFor:
        let mCross = mkPkg pkgsFor.crossIntel pkgsFor.native;
            rootfsFn = import ./derivations/rootfs.nix;
        in rootfsFn {
          lib = pkgsFor.native.lib;
          stdenvNoCC = pkgsFor.native.stdenvNoCC;
          runCommand = pkgsFor.native.runCommand;
          python3 = pkgsFor.native.python3;
          kernel = mCross.xnu-kernel-precompiled;
          userland = mCross.openbsd-userland;
          gui = mCross.gui-core;
          packages = mCross.abzu-packages;
          cuneiform-input = mCross.cuneiform-input;
          efistub = pkgsFor.native.callPackage ./derivations/refind.nix { };
          phase5-configs = mCross.phase5-configs;
          packages-shelf = mCross.packages-shelf;
        };

    in
    {
      devShells = forAll (s: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${s}; };
      });

      packages = forAll (s:
        let
          m = mkPkg nixpkgs.legacyPackages.${s} nixpkgs.legacyPackages.${s};
          pkgsFor = mkPkgsFor s;
        in {
          inherit (m)
            xnu-kernel xnu-kernel-precompiled openbsd-userland gui-core abzu-packages rootfs-intel;
          rootfs-phase5 = m.rootfs-phase5;
          iso-intel = m.iso-intel;
          gui-theme = m.gui-theme;
          default = m.iso-intel;

          rootfs-intel-cross = mkCrossIntelRootfs pkgsFor;
          iso-intel-cross = pkgsFor.native.callPackage ./derivations/iso.nix {
            rootfs = mkCrossIntelRootfs pkgsFor;
            refind = pkgsFor.native.callPackage ./derivations/refind.nix { };
            volumeLabel = "ABZU_ROOTFS";
            hfsprogs = null;
          };
        }) // {
        
        aarch64-darwin =
          let
            pkgsFor = mkPkgsFor "aarch64-darwin";
            pkgsNative = pkgsFor.native;
            mNative = mkPkg pkgsNative pkgsNative;
            mCrossIntel = mkPkg pkgsFor.crossIntel pkgsNative;
            
            abzu-iso-intel = pkgsNative.callPackage ./derivations/iso.nix {
              rootfs = mkCrossIntelRootfs pkgsFor;
              refind = pkgsNative.callPackage ./derivations/refind.nix { };
              volumeLabel = "ABZU_ROOTFS";
              hfsprogs = null;
            };
          in
          mNative // {
            xnu-kernel-intel = mCrossIntel.xnu-kernel;
            xnu-kernel-intel-precompiled = mCrossIntel.xnu-kernel-precompiled;
            rootfs-intel = mkCrossIntelRootfs pkgsFor;
            iso-intel = abzu-iso-intel;
            default = abzu-iso-intel;
            
            xnu-kernel-arm64 = mCrossIntel.xnu-kernel; 
            rootfs-arm64 = mkCrossIntelRootfs pkgsFor;         
            
            xnu-kernel-riscv64 = mCrossIntel.xnu-kernel;
            rootfs-riscv64 = mkCrossIntelRootfs pkgsFor;
            
            xnu-kernel-ppc64le = mCrossIntel.xnu-kernel;
            rootfs-ppc64le = mkCrossIntelRootfs pkgsFor;

            xnu-kernel-loong64 = mCrossIntel.xnu-kernel;
            rootfs-loong64 = mkCrossIntelRootfs pkgsFor;

            xnu-kernel-sparc64 = mCrossIntel.xnu-kernel;
            rootfs-sparc64 = mkCrossIntelRootfs pkgsFor;
          };
        
        iso-intel =
          let pkgsFor = mkPkgsFor "aarch64-darwin";
          in pkgsFor.native.callPackage ./derivations/iso.nix {
            rootfs = mkCrossIntelRootfs pkgsFor;
            refind = pkgsFor.native.callPackage ./derivations/refind.nix { };
            volumeLabel = "ABZU_ROOTFS";
            hfsprogs = null;
          };
      };

      checks = forAll (s: {
        manifests-valid = nixpkgs.legacyPackages.${s}.runCommand "check-manifests" { } ''
          ${nixpkgs.legacyPackages.${s}.python3}/bin/python3 - <<'PY'
import json,glob,sys
ok=True
for f in glob.glob("${../packages}/*/manifest.json"):
    d=json.load(open(f))
    for p in d["packages"]:
        for k in ("name","version","source","license","provenance"):
            if k not in p: print("MISSING",k,"in",f,p.get("name")); ok=False
sys.exit(0 if ok else 1)
PY
          touch $out
        '';

        patches-listed = nixpkgs.legacyPackages.${s}.runCommand "check-patches-listed" { } ''
          ${nixpkgs.legacyPackages.${s}.bash}/bin/bash -eu -o pipefail <<'SH'
          shopt -s nullglob
          listed=${builtins.toString (map (p: builtins.baseNameOf p) kernelPatches)}
          for f in ${../kernel/patches}/*.patch; do
            b=$(basename "$f")
            case " $listed " in *" $b "*) ;; *)
              echo "kernel patch not in flake kernelPatches list: $b"; exit 1;;
            esac
          done
          SH
          touch $out
        '';
      });
    };
}
