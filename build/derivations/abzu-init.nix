# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;
  
  # CRITICAL FIX: Tell Nix this is a raw file, not a .tar.gz archive.
  # This skips the unpackPhase and lets us compile the .c file directly.
  dontUnpack = true;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # Compile a Universal Binary (fat binary) for Intel architectures.
    # The native M4 clang has the x86_64 backend built-in.
    clang -arch i386 -arch x86_64 \
      -nostdlib -static -e _start -O2 \
      -o abzu $src
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp abzu $out/sbin/abzu
    chmod +x $out/sbin/abzu
  '';
}
