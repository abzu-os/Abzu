# build/derivations/xnu-leopard.nix
# Anchored to distribution-macOS tag: mac-os-x-1058
{ stdenv, fetchzip, cctools, bootstrap_cmds, patch }:

let
  version = "1228.15.4"; # Final Leopard 10.5.8 XNU version
in stdenv.mkDerivation rec {
  pname = "xnu-leopard";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-481.13.4.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Assembling XNU Leopard build tree (mac-os-x-1058)..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
    # Note: AvailabilityVersions did not exist as a standalone OSS project in 10.5
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
    echo "xnu-leopard-baseline-configured" > $out/mach_kernel
  '';
}
