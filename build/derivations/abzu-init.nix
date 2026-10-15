# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;
  
  # Tell Nix this is a raw file, not a .tar.gz archive.
  dontUnpack = true;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # Compile a Universal Binary for Intel architectures.
    # We use -e _main because the C function 'main' compiles to '_main' 
    # in the object file for both i386 and x86_64 on Darwin.
    clang -arch i386 -arch x86_64 \
      -nostdlib -static -e _main -O2 \
      -o abzu $src
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp abzu $out/sbin/abzu
    chmod +x $out/sbin/abzu
  '';
}
