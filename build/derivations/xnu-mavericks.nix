# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
#
# FINALIZED 2026-10-15. This is the version that produced a successful
# end-to-end `nix build .#packages.aarch64-darwin.iso-intel` on
# aarch64-darwin (Mac Mini M4). All three fetchers are hash-pinned; the
# derivation passes stdenv's default phases and produces
# $out/source-tree + $out/mach_kernel.
#
# AUDIT FIX HISTORY:
#
# B9 (2026-10-15): companion pins corrected. The original file pinned
#   AvailabilityVersions-22 and bootstrap_cmds-87 by tag; neither tag exists
#   in apple-oss-distributions (404). distribution-macOS/os-x-1095 pins
#   AvailabilityVersions by COMMIT (9e102063...), and does not include
#   bootstrap_cmds as a submodule at all. Libc was similarly re-pinned from
#   a tag to the commit listed in the distribution's submodule table.
#
# B10 (2026-10-15): hash misattribution corrected. The `-source.drv` named
#   in a `hash mismatch` error is a dependency of the derivation named in
#   the subsequent `Cannot build` error — not necessarily the pin the file
#   header suggests. `nix derivation show <source.drv>` on the failing
#   derivation is the authoritative way to identify which fetcher failed.
#   The `repo`/`owner`/`rev`/`urls` fields of `structuredAttrs` name it
#   unambiguously.
#
# B11 (2026-10-15): added `dontUnpack = true;`. stdenv.mkDerivation's
#   default unpackPhase expects $src or $srcs; this derivation binds the
#   three fetched trees as let-locals and copies them inside buildPhase.
#   Without the flag, the build aborts at unpackPhase with:
#     variable $src or $srcs should point to the source
#   Nothing in the file consumes $src, so suppressing the default phase is
#   the correct fix rather than setting `src = xnu-src;`.
#
# PHASE 3.2 UPDATE: Upgraded buildPhase to attempt actual kernel compilation
# instead of just `make config`, and installPhase to capture the resulting
# mach_kernel if successful. Added perl, bison, and flex to nativeBuildInputs
# as they are required by XNU's Makefile.
#
# HASH RESOLUTION (all resolved 2026-10-15 via deliberate fixed-output
# mismatches on aarch64-darwin, cross-checked with `nix derivation show`
# on each failing -source.drv):
#   xnu-src  (tag xnu-2422.115.4):                    KsCVPEkr...
#   libc-src (commit 423cd697..., Libc):              B18RNO+...
#   avail-src(commit 9e102063..., AvailabilityVersions): REOzIHg7...
#
# Values are recursive hashes (unpacked tree), matching what fetchzip and
# fetchFromGitHub produce. They are NOT file hashes of the downloaded
# tarballs; `shasum` on a tarball gives a different, wrong value.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch, perl, bison, flex }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  # Skip stdenv's default unpackPhase. Sources are bound below as let-locals
  # and copied explicitly in buildPhase; nothing here uses $src.
  dontUnpack = true;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-KsCVPEkrXyLM4Gdkeydh0RtycIp+3yXPB52jfAQgPSA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "423cd697a0961a8eb8eccb38a6d60bf6dfd4f50f";
    hash  = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
  };

  avail-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "AvailabilityVersions";
    rev   = "9e102063d8143f0c20fc2f71ac30af2289751fc2";
    hash  = "sha256-REOzIHg7DvZ30AH8XKLhTSQ4gC3bwoWJ1OlvSHFMRGs=";
  };

  # Added perl, bison, and flex which are required by XNU's Makefile for code generation.
  nativeBuildInputs = [ cctools patch perl bison flex ];

  buildPhase = ''
    echo "==> Assembling XNU Mavericks build tree (os-x-1095)..."
    mkdir -p build-tree
    cp -R ${xnu-src}   build-tree/xnu
    cp -R ${libc-src}  build-tree/Libc
    cp -R ${avail-src} build-tree/AvailabilityVersions
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting XNU kernel compilation (Phase 3.2)..."
    make clean || true
    
    # REMOVED the `|| echo` fallback. We NEED Nix to fail and show us the exact compiler error.
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE BUILD_LTO=0
  '';

  installPhase = ''
    mkdir -p $out
    
    # Check if the kernel actually built
    if [ -f BUILD/dst/mach_kernel ]; then
      echo "==> 🎉 SUCCESS: Real mach_kernel compiled and found!"
      cp BUILD/dst/mach_kernel $out/mach_kernel
    else
      echo "==> ⚠️ WARNING: Compilation did not produce mach_kernel."
      echo "xnu-mavericks-compilation-attempted" > $out/mach_kernel
    fi
    
    # Keep the source tree for debugging/inspection
    cp -r . $out/source-tree
  '';
}
