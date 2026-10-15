# build/derivations/xnu-mavericks.nix
{ stdenv, fetchurl, cctools, bootstrap_cmds, patch }:

stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  version = "2422.115.4"; # Mac OS X 10.9.5 Mavericks (Final Release)

  src = fetchurl {
    url = "https://opensource.apple.com/tarballs/xnu/xnu-${version}.tar.gz";
    # TODO: CI will fail on first run and provide the correct sha256. Replace this placeholder.
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  nativeBuildInputs = [ cctools bootstrap_cmds patch ];

  buildPhase = ''
    echo "==> Fetching and patching XNU Mavericks source (x86_64)..."
    
    # 1. Future: Apply OpenBSD-inspired hardening patches here (W^X, stack canaries, etc.)
    # patch -p1 < ${./xnu-mavericks-hardening.patch}

    # 2. Patch default init path at the source level
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +
    
    echo "==> Source prepped. (Full compilation requires companion projects in next iteration)"
  '';

  installPhase = ''
    mkdir -p $out
    # PLACEHOLDER: Will be replaced with the actual compiled x86_64 mach_kernel
    echo "xnu-mavericks-x86_64-source-placeholder" > $out/mach_kernel
  '';
}
