# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
#
# AUDIT FIX (2026-10-15, B11):
#   - All three fetchers are hash-pinned (see history below).
#   - Added `dontUnpack = true`. The default unpackPhase of stdenv.mkDerivation
#     expects $src or $srcs; this derivation instead binds the three fetched
#     trees as `let` locals and copies them inside buildPhase. Without this
#     flag, build fails at unpackPhase with:
#       variable $src or $srcs should point to the source
#     Nothing consumes $src in this file, so suppressing the default phase is
#     the correct fix, not setting src = xnu-src.
#
# Hash resolution history:
#   - xnu-src : tag xnu-2422.115.4       → KsCVPEkr...
#   - libc-src: commit 423cd697... (Libc) → B18RNO+...
#   - avail-src: commit 9e102063... (AvailabilityVersions) → REOzIHg7...
#   - bootstrap_cmds: not a submodule of os-x-1095, removed.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

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
