# build/derivations/refind.nix
# rEFInd EFI bootloader (GPLv3) staged for the ISO's ESP image.
{ lib, stdenvNoCC, runCommand, fetchzip }:

let
  version = "0.14.0.2";
  src = fetchzip {
    url = "https://downloads.sourceforge.net/project/refind/${version}/refind-bin-${version}.zip";
    hash = "sha256-rlUQEbpQK+8HgWBoYjKpOHOhPHfnDj5jQpv7Q3+0CgE=";
    stripRoot = false;
  };
in runCommand "abzu-refind-${version}" {
  meta.description = "rEFInd ${version} EFI boot manager staged for Abzu";
} ''
  set -e
  mkdir -p $out/EFI/BOOT $out/EFI/refind
  # FIX: The binaries are nested inside the /refind subfolder of the extracted zip
  R="${src}/refind-bin-${version}/refind"
  
  # FIX: The files are actually named refind_x64.efi, not refind_x64
  # CRITICAL: EFI executables MUST be 755 (executable), or the firmware will reject them.
  # We removed '|| true' so the build fails loudly if the binaries are missing.
  install -m755 "$R/refind_x64.efi" $out/EFI/BOOT/BOOTX64.EFI
  install -m755 "$R/refind_ia32.efi" $out/EFI/BOOT/BOOTIA32.EFI # Critical for MBP 4,1 compatibility
  
  # Copy drivers and icons
  [ -d "$R/drivers_x64" ] && cp -r "$R/drivers_x64" $out/EFI/refind/drivers_x64 || true
  [ -d "$R/drivers_ia32" ] && cp -r "$R/drivers_ia32" $out/EFI/refind/drivers_ia32 || true
  [ -d "$R/icons" ] && cp -r "$R/icons" $out/EFI/refind/icons || true

  # Generate a clean, Abzu-themed rEFInd configuration.
  #
  # BOOT-CHAIN NOTE: XNU boots via its EFI boot stub (boot.efi), which the
  # rootfs stages at /System/Library/CoreServices/boot.efi; rEFInd must chain
  # that stub — pointing `loader` straight at \System\Library\Kernels\kernel
  # is invalid because mach_kernel is a Mach-O binary, not an PE/COFF EFI
  # application. The ISO's ESP also carries the standard fallback path
  # \EFI\BOOT\BOOTX64.EFI (= this rEFInd binary).
  cat > $out/EFI/refind/refind.conf <<'CONF'
timeout 5
showtools shutdown, reboot, exit
volume_label ABZU_ROOTFS
menuentry "Abzu Darwin" {
    icon \EFI\refind\icons\os_mac.png
    volume "ABZU_ROOTFS"
    loader \System\Library\CoreServices\boot.efi
    options "-abzu-mode root=UUID=ABZU-ROOTFS rdshell=0"
}
CONF
''
