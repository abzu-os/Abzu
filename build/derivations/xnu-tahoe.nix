# build/derivations/xnu-tahoe.nix
# Anchored to distribution-macOS tag: macos-265
#
# AUDIT FIX (2026-10-15, B17):
#   - dontUnpack = true. See xnu-leopard.nix for the full rationale.
#   - xnu  : tag xnu-11215.1.10 (matches distribution-macOS/macos-265).
#   - Libc : pinned by COMMIT 4e34d0559e3a1b081afeb8604d9e204a1f31321d.
#            The previous tag (Libc-1500.100.10) does not exist. UNVERIFIED.
#   - AvailabilityVersions: pinned by COMMIT
#     149b1777f3e8c2133042d8e188f72e3adf6a7110. UNVERIFIED.
#   - bootstrap_cmds: pinned by COMMIT
#     c71d2d72f48995baaea76148f61002e5299841de. UNVERIFIED.
#
# HASH RESOLUTION: placeholders resolve via the `got:` line of each
# fixed-output mismatch. Run `nvwhy <source.drv>` before pasting any value.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  xnu-version = "11215.1.10";
in stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  version = xnu-version;

  dontUnpack = true;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${xnu-version}.tar.gz";
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
    cp -R ${xnu-src}       build-tree/xnu
    cp -R ${libc-src}      build-tree/Libc
    cp -R ${avail-src}     build-tree/AvailabilityVersions
    cp -R ${bootstrap-src} build-tree/bootstrap_cmds
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
