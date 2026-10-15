# build/derivations/xnu-lion.nix
{ stdenv, fetchurl, cctools, bootstrap_cmds, patch }:

stdenv.mkDerivation rec {
  pname = "xnu-lion";
  version = "1699.32.7"; # Mac OS X 10.7 Lion (Final 32-bit kernel support)

  src = fetchurl {
    url = "https://opensource.apple.com/tarballs/xnu/xnu-${version}.tar.gz";
    # TODO: CI will fail on first run and provide the correct sha256. Replace this placeholder.
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Fetching and patching XNU Lion source (i386)..."
    
    # 1. Future: Apply OpenBSD-inspired hardening patches here
    # patch -p1 < ${./xnu-lion-hardening.patch}

    # 2. Patch default init path at the source level
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +
    
    echo "==> Source prepped. (Full compilation requires companion projects in next iteration)"
  '';

  installPhase = ''
    mkdir -p $out
    # PLACEHOLDER: Will be replaced with the actual compiled i386 mach_kernel
    echo "xnu-lion-i386-source-placeholder" > $out/mach_kernel
  '';
}
