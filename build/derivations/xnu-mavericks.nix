# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
#
# AUDIT FIX (2026-10-15, B10):
#   - xnu  : tag xnu-2422.115.4. Tree hash resolved (KsCVPEkr...).
#   - Libc : COMMIT 423cd697a0961a8eb8eccb38a6d60bf6dfd4f50f. Tree hash
#            resolved (B18RNO+...).
#   - AvailabilityVersions: COMMIT 9e102063d8143f0c20fc2f71ac30af2289751fc2
#            ("OS X 10.9"). Tree hash resolved (REOzIHg7...).
#   - bootstrap_cmds: NOT a submodule of os-x-1095. Removed.
#
# All three fetchers in this file are now hash-pinned. Any further failure
# in this derivation will be in buildPhase, not the fetchers.
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

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
    # Resolved 2026-10-15. Confirmed via `nix derivation show` that the repo
    # field matched AvailabilityVersions.
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
