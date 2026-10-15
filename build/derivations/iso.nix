# build/derivations/iso.nix
{ lib, stdenvNoCC, runCommand, rootfs, kernel, abzu-init, xorriso,
  mtools ? null, dosfstools ? null,
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
    cp -r --no-preserve=ownership,mode ${rootfs}/. work/iso_root/
    chmod -R u+w work/iso_root

    # 1. The kernel MUST be at the root of the drive as 'mach_kernel'
    cp ${kernel}/mach_kernel work/iso_root/mach_kernel
    
    # 2. Our custom init MUST be at /sbin/abzu
    mkdir -p work/iso_root/sbin
    cp ${abzu-init}/sbin/abzu work/iso_root/sbin/abzu
    chmod +x work/iso_root/sbin/abzu

    # Create the bootable structure
    mkdir -p work/iso_root/System/Library/CoreServices
    touch work/iso_root/System/Library/CoreServices/boot.efi

    tar --format=ustar --numeric-owner --owner=0 --group=0 \
        --mtime="@${builtins.toString 315532800}" \
        -C work/iso_root -cf work/ABZU_ROOTFS.tar .

    echo "==> Writing ISO9660+Joliet ISO..."
    xorriso -as mkisofs \
      -r -J -joliet-long \
      -V "${volumeLabel}" \
      -o abzu-intel-installer.iso \
      work/iso_root work/ABZU_ROOTFS.tar

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
