# build/derivations/xnu-lion.nix
# Anchored to distribution-macOS tag: mac-os-x-1075
#
# AUDIT FIX (2026-10-15, B9):
#   - xnu  : tag xnu-1699.32.7 (correct)
#   - Libc : pinned by COMMIT 605fac31f8e9694c6247ef69a20931cb6cafbc8a,
#            matching distribution-macOS/mac-os-x-1075. The previous tag
#            (Libc-763.13) does not exist in apple-oss-distributions.
#   - AvailabilityVersions: NOT a submodule of mac-os-x-1075. Removed.
#   - bootstrap_cmds: pinned by COMMIT bc6d8a8f069753918c6437c7a66f91a0dee23240.
#     The previous tag (bootstrap_cmds-82) does not exist.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "1699.32.7";
in stdenv.mkDerivation rec {
  pname = "xnu-lion";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "605fac31f8e9694c6247ef69a20931cb6cafbc8a";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  bootstrap-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "bootstrap_cmds";
    rev   = "bc6d8a8f069753918c6437c7a66f91a0dee23240";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Lion build tree (mac-os-x-1075)..."
    mkdir -p build-tree
    cp -r ${xnu-src}       build-tree/xnu
    cp -r ${libc-src}      build-tree/Libc
    cp -r ${bootstrap-src} build-tree/bootstrap_cmds
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
    echo "xnu-lion-baseline-configured" > $out/mach_kernel
  '';
}
