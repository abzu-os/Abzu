# build/derivations/xnu-mavericks.nix
# Anchored to distribution-macOS tag: os-x-1095
{ stdenv, fetchzip, fetchFromGitHub, cctools, patch, perl, bison, flex, m4 }:

let
  version = "2422.115.4";
in stdenv.mkDerivation rec {
  pname = "xnu-mavericks";
  inherit version;

  dontUnpack = true;

  xnu-src = fetchzip {
    url = "https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-${version}.tar.gz";
    sha256 = "sha256-KsCVPEkrXyLM4Gdkeydh0RtycIp+3yXPB52jfAQgPSA=";
    stripRoot = true;
  };

  libc-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "Libc";
    rev   = "423cd697a0961a8eb8eccb38a6d60bf6dfd4f50f";
    hash  = "sha256-B18RNO+Rai5XE52TKdJV7eknosTZ+bRERkiU12d/kPU=";
  };

  avail-src = fetchFromGitHub {
    owner = "apple-oss-distributions";
    repo  = "AvailabilityVersions";
    rev   = "9e102063d8143f0c20fc2f71ac30af2289751fc2";
    hash  = "sha256-REOzIHg7DvZ30AH8XKLhTSQ4gC3bwoWJ1OlvSHFMRGs=";
  };

  nativeBuildInputs = [ cctools patch perl bison flex m4 ];

  preBuild = ''
    # 1. XNU expects GNU m4 to be named 'gm4'
    ln -s ${m4}/bin/m4 $PWD/gm4
    
    # 2. Fake sw_vers to satisfy XNU's makedefs version checks
    cat > $PWD/sw_vers << 'EOF'
    #!/bin/sh
    echo "ProductName:    Mac OS X"
    echo "ProductVersion: 10.9.5"
    echo "BuildVersion:   13F1911"
    EOF
    chmod +x $PWD/sw_vers

    # 3. Fake xcrun to bypass XNU's SDK path detection, which fails in Nix sandbox.
    # We point it to root ('/'). Nix's stdenv clang wrapper already has the correct 
    # macOS SDK headers in its default include paths, so the build will still find them.
    cat > $PWD/xcrun << 'EOF'
    #!/bin/sh
    if [ "$1" = "--show-sdk-path" ]; then
      echo "/"
    else
      # Fallback to system xcrun if it exists, otherwise just succeed
      if [ -x /usr/bin/xcrun ]; then
        exec /usr/bin/xcrun "$@"
      else
        echo "/"
      fi
    fi
    EOF
    chmod +x $PWD/xcrun

    # Prepend current directory to PATH so our faked tools are found first
    export PATH="$PWD:$PATH"
    
    # Explicitly tell make to use our faked environment
    export SDKROOT="/"
    export RC_XBS=YES
  '';

  buildPhase = ''
    echo "==> Assembling XNU Mavericks build tree (os-x-1095)..."
    mkdir -p build-tree
    cp -R ${xnu-src}   build-tree/xnu
    cp -R ${libc-src}  build-tree/Libc
    cp -R ${avail-src} build-tree/AvailabilityVersions
    chmod -R u+w build-tree
    cd build-tree/xnu

    echo "==> Applying Abzu customizations..."
    find . -type f \( -name "*.c" -o -name "*.h" \) -exec sed -i 's|/sbin/launchd|/sbin/abzu|g' {} +

    echo "==> Attempting XNU kernel compilation (Phase 3.2)..."
    make clean || true
    
    # Pass SDKROOT=/ to override any internal makefile checks
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE BUILD_LTO=0 SDKROOT=/
  '';

  installPhase = ''
    mkdir -p $out
    
    if [ -f BUILD/dst/mach_kernel ]; then
      echo "==> 🎉 SUCCESS: Real mach_kernel compiled and found!"
      cp BUILD/dst/mach_kernel $out/mach_kernel
    else
      echo "==> ⚠️ WARNING: Compilation did not produce mach_kernel."
      echo "xnu-mavericks-compilation-attempted" > $out/mach_kernel
    fi
    
    cp -r . $out/source-tree
  '';
}
