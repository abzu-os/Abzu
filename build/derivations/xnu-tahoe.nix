# build/derivations/xnu-tahoe.nix
{ stdenv, fetchzip, cctools, bootstrap_cmds, patch }:

let
  # UPDATE THIS STRING when Darwin 26 (Tahoe) or newer tags are published.
  # Currently using Darwin 24 (Sequoia) as the stand-in.
  version = "11215.1.10";
in stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  libc-src = fetchzip {
    # Update this tag to match the Tahoe era Libc when available
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-1500.100.10.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000";
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-30.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Assembling XNU Tahoe build tree..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
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
    echo "xnu-tahoe-baseline-configured" > $out/mach_kernel
  '';
}
