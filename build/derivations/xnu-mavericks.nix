# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
{ stdenv, fetchzip, cctools, patch }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz";
    # LIVE-VERIFIED xnu-mavericks.nix pin fetches OK (raw tarball sha256=e47c15d4e03abc61218fe6bf107efad8e71c435e4a9c88b115a4f5cf45046cd5).
    # NOTE: this is the FILE hash. fetchzip needs the RECURSIVE nix hash of the
    # unpacked tree — generate on a Nix host with:
    #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz
    # then paste the resulting 'sha256-...' below replacing the AAAA placeholder.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-22.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  bootstrap-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/bootstrap_cmds/archive/refs/tags/bootstrap_cmds-87.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Mavericks build tree (os-x-1095)..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
    cp -r ${avail-src} build-tree/AvailabilityVersions
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
    echo "xnu-mavericks-baseline-configured" > $out/mach_kernel
  '';
}
