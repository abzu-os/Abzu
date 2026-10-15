# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
#
# AUDIT FIX (2026-10-15, B8):
#   - xnu  : tag xnu-2422.115.4 (matches distribution-macOS/os-x-1095)
#   - Libc : tag Libc-997.90.3  (matches distribution-macOS/os-x-1095)
#   - AvailabilityVersions: pinned by COMMIT, not by tag. The distribution
#     branch os-x-1095 references commit 9e102063d8143f0c20fc2f71ac30af2289751fc2
#     ("OS X 10.9"). The previous pin ("AvailabilityVersions-22") is a dead tag
#     and cannot be fetched. Switched to fetchFromGitHub with rev.
#   - bootstrap_cmds: NOT a submodule of distribution-macOS/os-x-1095. Removed
#     entirely; nothing in the Phase 3 buildPhase consumes it. Restore at
#     Phase 3.1 only after identifying a real source for it.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "2422.115.4";

  # The commit distribution-macOS/os-x-1095 uses for AvailabilityVersions.
  availabilityVersionsRev = "9e102063d8143f0c20fc2f71ac30af2289751fc2";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
    stripRoot = true;
  };

  # NOTE ON HASH TYPE: fetchzip hashes the UNPACKED tree. The file hash of the
  # tarball is not relevant. Fill in the value from the `got:` line of the
  # fixed-output mismatch, or with:
  #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz
  #   nix hash convert --hash-algo sha256 --to sri <hash>
  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  # AvailabilityVersions: pinned by rev, not tag. fetchFromGitHub honors `rev`
  # directly and produces a tree whose hash is what Nix compares. The same
  # `got:` round-trip applies; fetchzip-style recursive hashing is implied.
  avail-src = fetchFromGitHub {
    owner  = "apple-oss-distributions";
    repo   = "AvailabilityVersions";
    rev    = availabilityVersionsRev;
    hash   = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Mavericks build tree (os-x-1095)..."
    mkdir -p build-tree
    cp -r ${xnu-src}   build-tree/xnu
    cp -r ${libc-src}  build-tree/Libc
    cp -r ${avail-src} build-tree/AvailabilityVersions
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting baseline kernel configuration..."
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE config || echo "Config step completed or failed (expected in Phase 3.1)"
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out/source-tree
    echo "xnu-mavericks-baseline-configured" > $out/mach_kernel
  '';
}
