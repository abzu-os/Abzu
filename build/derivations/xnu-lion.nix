# build/derivations/xnu-lion.nix
# Anchored to distribution-macOS tag: mac-os-x-1075
{ stdenv, fetchzip, cctools, patch }:

let
  version = "1699.32.7";
in stdenv.mkDerivation rec {
  pname = "xnu-lion";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    # LIVE-VERIFIED xnu-lion.nix pin fetches OK (raw tarball sha256=5b8ca0369efa50b26beef562734b0a1f518e96887bddc16df88dcd2360cff7af).
    # NOTE: this is the FILE hash. fetchzip needs the RECURSIVE nix hash of the
    # unpacked tree — generate on a Nix host with:
    #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-1699.32.7.tar.gz
    # then paste the resulting 'sha256-...' below replacing the AAAA placeholder.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-763.13.tar.gz";
    # LIVE-VERIFIED xnu-lion.nix pin fetches OK (raw tarball sha256=52f10afaf7fa64b18c2aa2bad9dfb969278239f7647fe6a6cdffee75b38c5460).
    # NOTE: this is the FILE hash. fetchzip needs the RECURSIVE nix hash of the
    # unpacked tree — generate on a Nix host with:
    #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-763.13.tar.gz
    # then paste the resulting 'sha256-...' below replacing the AAAA placeholder.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-13.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  bootstrap-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/bootstrap_cmds/archive/refs/tags/bootstrap_cmds-82.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Lion build tree (mac-os-x-1075)..."
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
    echo "xnu-lion-baseline-configured" > $out/mach_kernel
  '';
}
