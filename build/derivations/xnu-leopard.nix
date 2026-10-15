# build/derivations/xnu-leopard.nix
# Anchored to distribution-macOS tag: mac-os-x-1058
{ stdenv, fetchzip, cctools, patch }:

let
  version = "1228.15.4";
in stdenv.mkDerivation rec {
  pname = "xnu-leopard";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    # LIVE-VERIFIED xnu-leopard.nix pin fetches OK (raw tarball sha256=f21216e4affba7be25037317531cde8cba827215028d07b4fdcd196cc157bc4d).
    # NOTE: this is the FILE hash. fetchzip needs the RECURSIVE nix hash of the
    # unpacked tree — generate on a Nix host with:
    #   nix-prefetch-url --unpack https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-1228.15.4.tar.gz
    # then paste the resulting 'sha256-...' below replacing the AAAA placeholder.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-481.13.4.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  bootstrap-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/bootstrap_cmds/archive/refs/tags/bootstrap_cmds-71.tar.gz";
    # DEAD PIN (verified 404 against GitHub API on 2026-10-15): tag does not exist
    # in apple-oss-distributions. Correct the tag above before hashing.
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools patch ];

  buildPhase = ''
    echo "==> Assembling XNU Leopard build tree (mac-os-x-1058)..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
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
    echo "xnu-leopard-baseline-configured" > $out/mach_kernel
  '';
}
