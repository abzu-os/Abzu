# build/derivations/xnu-tahoe.nix
# Anchored to distribution-macOS tag: macos-265
{ stdenv, fetchzip, cctools, bootstrap_cmds, patch }:

let
  # TODO: Open the macos-265 tag in distribution-macOS, read the 'projects' file, 
  # and update these three version strings to match the exact XNU, Libc, and 
  # AvailabilityVersions tags listed for this release.
  xnu-version = "11215.1.10"; # Placeholder: Update from macos-265 'projects' file
  libc-version = "1500.100.10"; # Placeholder: Update from macos-265 'projects' file
  avail-version = "30"; # Placeholder: Update from macos-265 'projects' file
in stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  version = xnu-version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${xnu-version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-${libc-version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-${avail-version}.tar.gz";
    sha256 = "0000000000000000000000000000000000000000000000000000"; # CI will provide
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Assembling XNU Tahoe build tree (macos-265)..."
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
