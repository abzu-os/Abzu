# build/derivations/xnu-tahoe.nix
{ stdenv, fetchurl, cctools, bootstrap_cmds, patch }:

stdenv.mkDerivation rec {
  pname = "xnu-tahoe";
  # Using a recent Darwin 24/25 tag as a stand-in until the exact Darwin 26 
  # tag is published by Apple. Update this when the Tahoe source drops.
  version = "11215.1.10"; 

  src = fetchurl {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    # TODO: CI will fail on first run and provide the correct sha256. Replace this placeholder.
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Fetching and patching XNU Tahoe source (x86_64)..."
    
    # 1. Future: Apply OpenBSD-inspired hardening patches here
    # patch -p1 < ${./xnu-tahoe-hardening.patch}

    # 2. Patch default init path at the source level
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +
    
    echo "==> Source prepped. (Full compilation requires companion projects in next iteration)"
  '';

  installPhase = ''
    mkdir -p $out
    # PLACEHOLDER: Will be replaced with the actual compiled x86_64 mach_kernel
    echo "xnu-tahoe-x86_64-source-placeholder" > $out/mach_kernel
  '';
}
