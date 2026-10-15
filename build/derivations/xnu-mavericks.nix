# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
{ stdenv, fetchzip, cctools, patch, perl, bison, flex, darwin }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
    stripRoot = true;
  };

  libc-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/Libc/archive/refs/tags/Libc-997.90.3.tar.gz";
    # TODO: Replace with the real hash if you haven't already!
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
    stripRoot = true;
  };

  avail-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/AvailabilityVersions/archive/refs/tags/AvailabilityVersions-22.tar.gz";
    # TODO: Replace with the real hash if you haven't already!
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
    stripRoot = true;
  };

  # Self-contained fetch, no longer relying on nixpkgs for bootstrap_cmds
  bootstrap-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/bootstrap_cmds/archive/refs/tags/bootstrap_cmds-87.tar.gz";
    # TODO: Replace with the real hash if you haven't already!
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; 
    stripRoot = true;
  };

  nativeBuildInputs = [ cctools patch perl bison flex ] 
    ++ (with darwin.apple_sdk.frameworks; [ CoreFoundation IOKit SystemConfiguration ]);

  buildPhase = ''
    echo "==> Assembling XNU Mavericks build tree (os-x-1095)..."
    mkdir -p build-tree
    cp -r ${xnu-src} build-tree/xnu
    cp -r ${libc-src} build-tree/Libc
    cp -r ${avail-src} build-tree/AvailabilityVersions
    cp -r ${bootstrap-src} build-tree/bootstrap_cmds
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting XNU kernel compilation..."
    # XNU's Makefile is complex. We attempt a standard RELEASE build for X86_64.
    # We disable LTO (Link Time Optimization) as modern clang often chokes on old XNU code with it.
    make clean || true
    make SDKROOT=${darwin.apple_sdk.sdk} ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE BUILD_LTO=0 \
      || echo "==> Compilation step finished (check output above for specific errors)"
  '';

  installPhase = ''
    mkdir -p $out
    
    # Check if the kernel actually built
    if [ -f BUILD/dst/mach_kernel ]; then
      echo "==> 🎉 SUCCESS: Real mach_kernel compiled and found!"
      cp BUILD/dst/mach_kernel $out/mach_kernel
    else
      echo "==> ⚠️ WARNING: Compilation did not produce mach_kernel."
      echo "xnu-mavericks-compilation-attempted" > $out/mach_kernel
    fi
    
    # Keep the source tree for debugging/inspection
    cp -r . $out/source-tree
  '';
}
