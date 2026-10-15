# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # The NATIVE arm64 clang on your M4 Mac has the x86_64 backend built-in.
    # It compiles x86_64 machine code natively without Rosetta.
    
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
