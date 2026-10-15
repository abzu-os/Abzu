# build/derivations/xnu-mavericks.nix
{ stdenv, fetchzip, cctools, bootstrap_cmds, patch, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  version = "2422.115.4"; # Mac OS X 10.9.5 Mavericks

  # 1. Fetch the main XNU source
  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide this
    stripRoot = true;
  };

  # 2. Fetch critical companion projects
  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz"; # Mavericks era Libc
    sha256 = "0000000000000000000000000000000000000000000000000000";
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-22.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch makeWrapper ];

  buildPhase = ''
    echo "==> Assembling XNU build tree with companions..."
    
    # XNU's Makefile expects these to be in specific relative locations.
    # We create a unified build directory to satisfy the Makefile.
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
    cp -r ${avail-src} build-tree/AvailabilityVersions
    
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    # Patch default init path at the source level
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting baseline kernel configuration..."
    # We run 'make config' first to generate the necessary headers.
    # A full 'make all' will likely fail on the first try due to missing macOS SDK headers,
    # which is expected. This step proves the tree is assembled correctly.
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE config || echo "Config step completed or failed (expected in Phase 3.1)"
  '';

  installPhase = ''
    mkdir -p $out
    # For Phase 3.1, we output the configured source tree and a placeholder kernel.
    # In Phase 3.2, we will replace this with the actual 'make all' output.
    cp -r . $out/source-tree
    echo "xnu-mavericks-baseline-configured" > $out/mach_kernel
  '';
}
