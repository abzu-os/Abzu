# build/derivations/iso.nix
{ lib, stdenvNoCC, runCommand, rootfs, refind, xorriso, abzu-init, xnu,
  mtools ? null, dosfstools ? null, libisoburn ? null,
  isolinux ? null,          
  hfsutils ? null,          
  hfsprogs ? null,          
  volumeLabel ? "ABZU_ROOTFS" }:

stdenvNoCC.mkDerivation rec {
  pname = "abzu-iso-intel";
  version = "0.2.0"; # Phase 2

  nativeBuildInputs = [ xorriso ]
    ++ builtins.filter (x: x != null) [ mtools dosfstools libisoburn hfsutils hfsprogs ];

  buildCommand = ''
    runHook preBuild
    export SOURCE_DATE_EPOCH="315532800"
    export TZ=UTC
    export MTOOLS_SKIP_CHECK=1

    top="$PWD"
    mkdir -p work/iso_root work/esp/EFI/BOOT work/esp/EFI/refind

    # ---- 1. Stage the Darwin rootfs & Abzu Components --------------------
    echo "==> Staging rootfs and Abzu components..."
    cp -r --no-preserve=ownership,mode ${rootfs}/. work/iso_root/
    chmod -R u+w work/iso_root

    # LEOPARD ARCHITECTURE FIX:
    # 1. The kernel MUST be at the root of the drive as 'mach_kernel'
    cp ${xnu}/mach_kernel work/iso_root/mach_kernel
    
    # 2. Our custom init MUST be at /sbin/abzu
    mkdir -p work/iso_root/sbin
    cp ${abzu-init}/sbin/abzu work/iso_root/sbin/abzu
    chmod +x work/iso_root/sbin/abzu

    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="@${builtins.toString 315532800}" \
        -C work/iso_root -cf work/ABZU_ROOTFS.tar .

    # ---- 2. Build the EFI System Partition image --------------------------
    echo "==> Building ESP image..."
    cp -r --no-preserve=ownership ${refind}/EFI/BOOT/.  work/esp/EFI/BOOT/
    cp -r --no-preserve=ownership ${refind}/EFI/refind/. work/esp/EFI/refind/
    
    # Copy boot.efi from the rootfs if it exists (for rEFInd chaining)
    if [ -f work/iso_root/System/Library/CoreServices/boot.efi ]; then
      mkdir -p work/esp/System/Library/CoreServices
      cp work/iso_root/System/Library/CoreServices/boot.efi \
         work/esp/System/Library/CoreServices/boot.efi
    fi

    dd if=/dev/zero of=work/esp.img bs=1M count=64 status=none
    ${if dosfstools != null && mtools != null then ''
      mkfs.vfat -F 32 -n ABZU_EFI work/esp.img >/dev/null
      mcopy -s -i work/esp.img work/esp/EFI ::/EFI
      if [ -d work/esp/System ]; then mcopy -s -i work/esp.img work/esp/System ::/System; fi
      mmd -i work/esp.img ::/SystemLibrary 2>/dev/null || true
    '' else ''
      echo "ERROR: mtools + dosfstools are required to build the ESP image." >&2
      exit 1
    ''}

    # ---- 3. Hybrid El Torito ISO -------------------------------------------
    echo "==> Writing hybrid ISO..."
    ISOHDPFX="${if isolinux != null then "${isolinux}/isohdpfx.bin" else ""}"

    # 1-sector dummy BIOS boot image to satisfy libisofs
    dd if=/dev/zero of=work/efiboot.img bs=2048 count=1 status=none
    
    cp work/efiboot.img work/iso_root/efiboot.img
    cp work/esp.img work/iso_root/esp.img
    
    # Copy the EFI directory to the ISO root for maximum Apple firmware compatibility
    cp -r work/esp/EFI work/iso_root/EFI

    xorriso -as mkisofs \
      -r -J -joliet-long \
      ${if hfsutils != null then "-hfs" else ""} \
      -V "${volumeLabel}" \
      ${if isolinux != null then "-isohybrid-mbr $ISOHDPFX" else ""} \
      -c boot.catalog \
      -b efiboot.img -no-emul-boot \
      -e esp.img -no-emul-boot \
      -isohybrid-gpt-basdat \
      -o abzu-intel-installer.iso \
      work/iso_root work/ABZU_ROOTFS.tar

    # Verify the El Torito catalog
    xorriso -indev abzu-intel-installer.iso -report_el_torito as_mkisofs > eltorito.txt
    grep -q "esp.img" eltorito.txt || { echo "FATAL: no El Torito EFI entry"; exit 1; }

    mkdir -p "$out"
    cp abzu-intel-installer.iso "$out/abzu-intel-installer.iso"
    sha256sum "$out/abzu-intel-installer.iso" > "$out/abzu-intel-installer.iso.sha256"
    echo "==> Phase 2 ISO created at: $out/abzu-intel-installer.iso"
    runHook postBuild
  '';

  meta = with lib; {
    description = "Bootable hybrid El Torito ISO for Abzu Darwin (Leopard Architecture)";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
