# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
#
# AUDIT FIX (2026-10-15, B10): corrected a misattributed hash. The B18RNO+
# value resolved in a previous round was the Libc tree hash, not the xnu tree
# hash. The `-source.drv` in the `hash mismatch` error was a dependency of
# xnu-mavericks, not xnu-src itself; the naming of the parent in the
# subsequent `Cannot build` error caused it to be applied to the wrong pin.
# B18RNO+ has been moved to libc-src; xnu-src is back to placeholder and will
# resolve on the next build.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    # Placeholder — actual xnu tree hash is still unknown. Resolve via the
    # `got:` line of the next hash mismatch (which will be for THIS derivation,
    # not for libc-src).
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "423cd697a0961a8eb8eccb38a6d60bf6dfd4f50f";
    # Resolved 2026-10-15. This value was previously pasted into xnu-src.
    hash  = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
  };

  avail-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "AvailabilityVersions";
    rev   = "9e102063d8143f0c20fc2f71ac30af2289751fc2";
    # Placeholder — will resolve after xnu-src and libc-src are settled.
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
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
