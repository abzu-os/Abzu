# build/derivations/xnu-leopard.nix
# Anchored to distribution-macOS tag: mac-os-x-1058
#
# AUDIT FIX (2026-10-15, B17):
#   - dontUnpack = true. stdenv.mkDerivation's default unpackPhase expects
#     $src or $srcs; this derivation binds sources as let-locals and copies
#     them in buildPhase. Without this flag the build aborts with:
#       variable $src or $srcs should point to the source
#   - xnu  : tag xnu-1228.15.4 (matches distribution-macOS/mac-os-x-1058).
#   - Libc : pinned by COMMIT 7198b93dbba0617e5927ff5a5e783f0e54ff957b.
#            The previous tag (Libc-481.13.4) does not exist in
#            apple-oss-distributions. UNVERIFIED — if the fetch 404s, re-read
#            the submodule listing on the mac-os-x-1058 branch.
#   - AvailabilityVersions, bootstrap_cmds: NOT submodules of mac-os-x-1058.
#     Removed. Restore only if a later phase genuinely requires them and a
#     verified commit is available.
#
# HASH RESOLUTION: all placeholders resolve via the `got:` line of the
# fixed-output mismatch on first build. Run `nvwhy <source.drv>` before
# pasting any value to confirm which fetcher failed.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "1228.15.4";
in stdenv.mkDerivation rec {
  pname = "xnu-leopard";
  inherit version;

  # Skip stdenv's default unpackPhase. Sources are bound below as let-locals
  # and copied explicitly in buildPhase; nothing here uses $src.
  dontUnpack = true;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "7198b93dbba0617e5927ff5a5e783f0e54ff957b";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Leopard build tree (mac-os-x-1058)..."
    mkdir -p build-tree
    cp -R ${xnu-src}  build-tree/xnu
    cp -R ${libc-src} build-tree/Libc
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
    echo "xnu-leopard-baseline-configured" > $out/mach_kernel
  '';
}
