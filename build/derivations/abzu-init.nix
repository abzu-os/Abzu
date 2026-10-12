# build/derivations/abzu-init.nix
{ stdenv, clang }:

stdenv.mkDerivation {
  pname = "abzu-init";
  version = "0.1.0";

  src = ./abzu-init.c;

  nativeBuildInputs = [ clang ];

  buildPhase = ''
    # Compile a statically linked Mach-O binary for x86_64
    # -nostdlib: Do not link against libSystem.dylib
    # -static: Ensure no dynamic linking
    # -e _start: Tell the linker our entry point is _start, not main
    clang -target x86_64-apple-darwin -nostdlib -static -e _start -O2 -o abzu $src
  '';

  installPhase = ''
    mkdir -p $out/sbin
    cp abzu $out/sbin/abzu
    chmod +x $out/sbin/abzu
  '';
}
