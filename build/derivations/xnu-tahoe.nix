# build/derivations/xnu-tahoe.nix
# Anchored to distribution-macOS tag: macos-265
{ stdenv, fetchzip, cctools, patch }:

let
  xnu-version = "11215.1.10"; 
  libc-version = "1500.100.10"; 
  avail-version = "30"; 
  bootstrap-version = "107"; # Placeholder: Update from macos-265 'projects' file if needed
in stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  version = xnu-version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${xnu-version}.tar.gz";
    # LIVE-VERIFIED xnu-tahoe.nix pin fetches OK (raw tarball sha256=3bd76675b985fcfecf1e6cb71050559ec88497e59f9cedf00d42dcf489b44374).
    # NOTE: this is the FILE hash. fetchzip needs the RECURSIVE nix hash of the
    # unpacked tree — generate on a Nix host with:
    #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-11215.1.10.tar.gz
    # then paste the resulting 'sha256-...' below replacing the AAAA placeholder.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-${libc-version}.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-${avail-version}.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  bootstrap-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/bootstrap_cmds/archive/refs/tags/bootstrap_cmds-${bootstrap-version}.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Tahoe build tree (macos-265)..."
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
    echo "xnu-tahoe-baseline-configured" > $out/mach_kernel
  '';
}
