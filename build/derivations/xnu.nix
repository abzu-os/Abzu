# build/derivations/xnu.nix
{ stdenv, kernelFile }:

stdenv.mkDerivation {
  pname = "xnu-abzu-patched";
  version = "0.1.0";

  # The pre-compiled kernel file from build/distfiles/kernel
  src = kernelFile;

  # We are operating on a single binary, not a tarball
  dontUnpack = true;

  buildPhase = ''
    echo "==> Patching kernel to bypass launchd..."
    cp $src mach_kernel

    # The string "/sbin/launchd" is 14 bytes (13 chars + null terminator). 
    # The string "/sbin/abzu" is 11 bytes (10 chars + null terminator).
    # We pad with 3 null bytes (\x00) to maintain the exact 14-byte footprint,
    # preventing the binary structure from shifting and corrupting.
    perl -pi -e 's/\/sbin\/launchd/\/sbin\/abzu\x00\x00\x00/g' mach_kernel
    
    # Verify the patch was successful
    strings mach_kernel | grep "/sbin/abzu" > /dev/null || { echo "FATAL: Kernel patch failed"; exit 1; }
    echo "==> Kernel successfully patched to look for /sbin/abzu"
  '';

  installPhase = ''
    mkdir -p $out
    # Leopard architecture requires the kernel to be named 'mach_kernel'
    cp mach_kernel $out/mach_kernel
  '';
}
