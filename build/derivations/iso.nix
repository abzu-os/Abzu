# build/derivations/iso.nix
{ lib, stdenvNoCC, runCommand, rootfs, kernel, abzu-init, xorriso,
  mtools ? null, dosfstools ? null,
  # AUDIT FIX (2026-10-15, B4): optional real Apple boot.efi payload
  # (catalina-signed). Default null => no zero-byte boot.efi is staged; the
  # tree carries an explicit .ABZU-NON-BOOTABLE marker unless efiPayload
  # (rEFInd) makes the image EFI-bootable to the installer at least.
  bootEfi ? null,
  # Real EFI boot binaries tree (e.g. refind.nix output with /EFI/BOOT/BOOTX64.EFI).
  efiPayload ? null,
  volumeLabel ? "ABZU_ROOTFS" }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.3.0"; # Phase 3: Source-Built Kernel

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
    # PORTABILITY (2026-10-15, B6): `cp --no-preserve=...` is GNU-only syntax
    # and matches the pattern that rootfs.nix's own audit note describes as
    # stripped for cross-platform compatibility. Use plain `cp -R` and
    # normalize writability afterward so the same command works with BSD cp
    # (macOS host toolchain) and GNU cp (Linux host toolchain).
    cp -R ${rootfs}/. work/iso_root/
    chmod -R u+w work/iso_root

    # 1. The kernel MUST be at the root of the drive as 'mach_kernel'
    cp ${kernel}/mach_kernel work/iso_root/mach_kernel
    chmod 644 work/iso_root/mach_kernel

    # 2. Our custom init MUST be at /sbin/abzu
    mkdir -p work/iso_root/sbin
    cp ${abzu-init}/sbin/abzu work/iso_root/sbin/abzu
    chmod +x work/iso_root/sbin/abzu

    # Create the bootable structure
    # AUDIT FIX (2026-10-15, B4): `touch boot.efi` staged a ZERO-byte file
    # that Intel Mac firmware happily selects and then hangs on. Only stage
    # boot.efi when a real binary is supplied via the bootEfi argument;
    # otherwise mark the image explicitly non-bootable inside the tree.
    mkdir -p work/iso_root/System/Library/CoreServices
    ${lib.optionalString (bootEfi != null) ''
      cp ${bootEfi} work/iso_root/System/Library/CoreServices/boot.efi
      chmod 644 work/iso_root/System/Library/CoreServices/boot.efi
    ''}${lib.optionalString (bootEfi == null) ''
      echo "no Apple boot.efi supplied (bootEfi argument)" > work/iso_root/.ABZU-BOOT-PARTIAL
    ''}
    # AUDIT FIX (2026-10-15, B4/A1): stage the rEFInd ESP payload so the ISO
    # actually boots (El Torito below). Without it the image is dry-run only.
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
      echo "NON-BOOTABLE: no EFI payload supplied (pass efiPayload=refind or use build/scripts/make-iso.sh ESP recipe)" \
        > work/iso_root/.ABZU-NON-BOOTABLE
    ''}

    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="1980-01-01 00:00:00 UTC" \
        -C work/iso_root -cf work/ABZU_ROOTFS.tar .

    echo "==> Writing ISO9660+Joliet ISO..."
    # AUDIT FIX (2026-10-15, B4): passing both work/iso_root AND the tar as
    # two image args made xorriso embed ABZU_ROOTFS.tar as a stray duplicate
    # file inside the very filesystem it also walked. Single tree only; move
    # the tar into the tree so the installer finds it at /ABZU_ROOTFS.tar.
    mv work/ABZU_ROOTFS.tar work/iso_root/ABZU_ROOTFS.tar
    chmod 644 work/iso_root/ABZU_ROOTFS.tar
    # El Torito EFI boot catalog + FAT-format ESP image when efiPayload present.
    #
    # AUDIT FIX (2026-10-15, B14): `bs=1m` is not portable. The Nix sandbox on
    # aarch64-darwin uses GNU dd from coreutils, which rejects the lowercase
    # `m` suffix (`1M` and `MiB` are accepted; `1m` is not). The redirect
    # `2>/dev/null` on the previous dd invocation hid the "invalid number"
    # error and `set -e` aborted the entire ISO build with no log output.
    # Use a bare byte count so the same command works on GNU dd, BSD dd, and
    # busybox dd; drop the stderr redirect so future failures surface.
    #
    # AUDIT FIX (2026-10-15, B15): `-hide-efi` and `-hidden-efi` are not
    # valid xorriso/mkisofs options in any version. xorriso 1.5.8.pl02
    # aborts with "FAILURE : -as mkisofs: Unrecognized option '-hide-efi'".
    # The intended effect — marking the ESP image as the EFI El Torito boot
    # entry — is already performed by `--efi-boot work/esp.img`. Both flags
    # removed.
    ${lib.optionalString (efiPayload != null) ''
      dd if=/dev/zero of=work/esp.img bs=1048576 count=8
      mkfs.vfat -F 12 -n ABZU_EFI work/esp.img >/dev/null
      mmd -i work/esp.img ::/EFI ::/EFI/BOOT ::/EFI/refind
      mcopy -i work/esp.img work/iso_root/EFI/BOOT/BOOTX64.EFI ::/EFI/BOOT/
      [ -f work/iso_root/EFI/BOOT/BOOTIA32.EFI ] && mcopy -i work/esp.img work/iso_root/EFI/BOOT/BOOTIA32.EFI ::/EFI/BOOT/ || true
      mcopy -i work/esp.img work/iso_root/EFI/refind/refind.conf ::/EFI/refind/
      # keep the plain-tree copy too so HFS-style mounts see it
    ''}# AUDIT FIX (2026-10-15, B6): `-isomax bridge` is not a valid xorriso or
    # mkisofs flag and aborts the ISO step with a usage error on every host.
    # EFI El Torito is already wired by `-e work/esp.img --efi-boot work/esp.img`
    # below; a true hybrid MBR would need `-isohybrid-mbr <path>` plus an MBR
    # blob, which is not staged here.
    #
    # AUDIT FIX (2026-10-15, B15): dropped `-hide-efi -hidden-efi` — see note
    # above the ESP staging block.
    xorriso -as mkisofs \
      -r -J -joliet-long \
      -V "${volumeLabel}" \
      ${lib.optionalString (efiPayload != null) "-e work/esp.img -no-emul-boot -boot-load-size 4 -boot-info-table --efi-boot work/esp.img"} \
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
