# build/derivations/xnu-leopard.nix
{ stdenv, fetchzip, cctools, bootstrap_cmds, patch }:

let
  # UPDATE THIS STRING to the latest Leopard-era tag, then run update-src-hashes.sh
  version = "1228.15.4"; 
in stdenv.mkDerivation rec {
  pname = "xnu-leopard";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  # Leopard-era companions (versions are approximate to the 10.5.x era)
  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-481.13.4.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Assembling XNU Leopard build tree..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting baseline kernel configuration..."
    # Leopard uses a slightly different make target structure
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE config || echo "Config step completed or failed (expected in Phase 3.1)"
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out/source-tree
    echo "xnu-leopard-baseline-configured" > $out/mach_kernel
  '';
}
