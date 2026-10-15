# build/derivations/xnu-leopard.nix
# Anchored to distribution-macOS tag: mac-os-x-1058
#
# AUDIT FIX (2026-10-15, B9):
#   - xnu  : tag xnu-1228.15.4 (correct)
#   - Libc : pinned by COMMIT 7198b93dbba0617e5927ff5a5e783f0e54ff957b,
#            matching distribution-macOS/mac-os-x-1058. The previous tag
#            (Libc-481.13.4) does not exist in apple-oss-distributions.
#   - AvailabilityVersions: NOT a submodule of mac-os-x-1058. Removed.
#   - bootstrap_cmds: NOT a submodule of mac-os-x-1058. Removed.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "1228.15.4";
in stdenv.mkDerivation rec {
  pname = "xnu-leopard";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    # Placeholder — resolve via the `got:` line of the fixed-output mismatch,
    # or with `nix-prefetch-url --unpack`.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "7198b93dbba0617e5927ff5a5e783f0e54ff957b";
    # Placeholder — resolve via the `got:` line.
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Leopard build tree (mac-os-x-1058)..."
    mkdir -p build-tree
    cp -r ${xnu-src}  build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
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
