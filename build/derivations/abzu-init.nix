# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # Compile a statically linked Mach-O binary for x86_64
    clang -target x86_64-apple-darwin -static -O2 -o abzu_init $src
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp abzu_init $out/sbin/abzu
    chmod +x $out/sbin/abzu
  '';
}
