# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # Compile a Universal Binary (fat binary) for Intel architectures.
    # We omit 'ppc' here because Apple's native clang no longer supports it.
    # The kernel's exec() will automatically select the matching slice at runtime.
    
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
