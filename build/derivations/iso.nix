# build/derivations/iso.nix
{ lib, stdenvNoCC, runCommand, rootfs, kernel, abzu-init, xorriso,
  mtools ? null, dosfstools ? null,
  bootEfi ? null,
  efiPayload ? null,
  volumeLabel ? "ABZU_ROOTFS" }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.3.0";

  nativeBuildInputs = [ xorriso ]
    ++ builtins.filter (x: x != null) [ mtools dosfstools ];

  buildCommand = ''
    runHook preBuild
    export SOURCE_DATE_EPOCH="315532800"
    export TZ=UTC
    export MTOOLS_SKIP_CHECK=1

    top="$PWD"
    mkdir -p work/iso_root

    echo "==> Staging rootfs and Abzu components..."
    cp -R ${rootfs}/. work/iso_root/
    chmod -R u+w work/iso_root

    cp ${kernel}/mach_kernel work/iso_root/mach_kernel
    chmod 644 work/iso_root/mach_kernel

    mkdir -p work/iso_root/sbin
    cp ${abzu-init}/sbin/abzu work/iso_root/sbin/abzu
    chmod +x work/iso_root/sbin/abzu

    mkdir -p work/iso_root/System/Library/CoreServices
    ${lib.optionalString (bootEfi != null) ''
      cp ${bootEfi} work/iso_root/System/Library/CoreServices/boot.efi
      chmod 644 work/iso_root/System/Library/CoreServices/boot.efi
    ''}${lib.optionalString (bootEfi == null) ''
      echo "no Apple boot.efi supplied (bootEfi argument)" > work/iso_root/.ABZU-BOOT-PARTIAL
    ''}

    ${lib.optionalString (efiPayload != null) ''
      mkdir -p work/iso_root/EFI
      cp -R ${efiPayload}/EFI/. work/iso_root/EFI/
      chmod -R u+w work/iso_root/EFI
      find work/iso_root/EFI -type f -name '*.EFI' -exec chmod 755 {} \;
      cat > work/iso_root/EFI/refind/refind.conf <<'REFINDDONE'
timeout 3
defaultloader efi
scan_all_windows false
also_scan_from /System/Library/Kernels
menu_title "Abzu Darwin"
default_boot mach_kernel
REFINDDONE
    ''}${lib.optionalString (efiPayload == null) ''
      echo "NON-BOOTABLE: no EFI payload supplied" > work/iso_root/.ABZU-NON-BOOTABLE
    ''}

    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="1980-01-01 00:00:00 UTC" \
        -C work/iso_root -cf work/ABZU_ROOTFS.tar .

    echo "==> Writing ISO9660+Joliet ISO..."
    mv work/ABZU_ROOTFS.tar work/iso_root/ABZU_ROOTFS.tar
    chmod 644 work/iso_root/ABZU_ROOTFS.tar

    # AUDIT FIX (2026-10-15, B16): xorriso's -e / --efi-boot options expect
    # paths RELATIVE to the ISO root, not host paths. Creating the ESP image
    # at work/esp.img and referencing it as `-e work/esp.img` made xorriso
    # search for /work/esp.img inside the ISO filesystem and abort with:
    #   xorriso : FAILURE : Cannot find path '/work/esp.img' in loaded ISO image
    # Fix: create the image at work/iso_root/boot/esp.img so it is part of the
    # ISO tree, and reference it as `boot/esp.img`.
    ${lib.optionalString (efiPayload != null) ''
      mkdir -p work/iso_root/boot
      dd if=/dev/zero of=work/iso_root/boot/esp.img bs=1048576 count=8
      mkfs.vfat -F 12 -n ABZU_EFI work/iso_root/boot/esp.img >/dev/null
      mmd -i work/iso_root/boot/esp.img ::/EFI ::/EFI/BOOT ::/EFI/refind
      mcopy -i work/iso_root/boot/esp.img work/iso_root/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/
      [ -f work/iso_root/EFI/BOOT/BOOTIA32.EFI ] && \
        mcopy -i work/iso_root/boot/esp.img work/iso_root/EFI/BOOT/BOOTIA32.EFI ::/EFI/BOOT/ || true
      mcopy -i work/iso_root/boot/esp.img work/iso_root/EFI/refind/refind.conf ::/EFI/refind/
    ''}xorriso -as mkisofs \
      -r -J -joliet-long \
      -V "${volumeLabel}" \
      ${lib.optionalString (efiPayload != null) "-e boot/esp.img -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot boot/esp.img"} \
      -o abzu-intel-installer.iso \
      work/iso_root

    mkdir -p "$out"
    cp abzu-intel-installer.iso "$out/abzu-intel-installer.iso"
    sha256sum "$out/abzu-intel-installer.iso" > "$out/abzu-intel-installer.iso.sha256"
    echo "==> Phase 3 ISO created at: $out/abzu-intel-installer.iso"
    runHook postBuild
  '';

  meta = {
    description = "ISO9660 container for Abzu Darwin (Source-built kernel)";
  };
}
