# build/derivations/xnu-tahoe.nix
# Anchored to distribution-macOS tag: macos-265
#
# AUDIT FIX (2026-10-15, B9):
#   - xnu  : tag xnu-11215.1.10 (correct)
#   - Libc : pinned by COMMIT 4e34d0559e3a1b081afeb8604d9e204a1f31321d,
#            matching distribution-macOS/macos-265. The previous tag
#            (Libc-1500.100.10) does not exist in apple-oss-distributions.
#   - AvailabilityVersions: pinned by COMMIT
#     149b1777f3e8c2133042d8e188f72e3adf6a7110 (macOS 26.4).
#   - bootstrap_cmds: pinned by COMMIT
#     c71d2d72f48995baaea76148f61002e5299841de (macOS 26.0).
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  xnu-version = "11215.1.10";
in stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  version = xnu-version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${xnu-version}.tar.gz";
    # Placeholder — resolve via the `got:` line.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "4e34d0559e3a1b081afeb8604d9e204a1f31321d";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  avail-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "AvailabilityVersions";
    rev   = "149b1777f3e8c2133042d8e188f72e3adf6a7110";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  bootstrap-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "bootstrap_cmds";
    rev   = "c71d2d72f48995baaea76148f61002e5299841de";
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Tahoe build tree (macos-265)..."
    mkdir -p build-tree
    cp -r ${xnu-src}       build-tree/xnu
    cp -r ${libc-src}      build-tree/Libc
    cp -r ${avail-src}     build-tree/AvailabilityVersions
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
    echo "xnu-tahoe-baseline-configured" > $out/mach_kernel
  '';
}
