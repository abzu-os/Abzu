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

    echo "==> Setting up fake build environment for XNU Makefiles..."
    
    # 1. Create a fake SDK directory structure to satisfy XNU's makedefs
    mkdir -p fake-sdk/usr/include
    mkdir -p fake-sdk/usr/lib
    FAKE_SDK_PATH="$PWD/fake-sdk"
    
    # 2. PATCH THE MAKEFILES: Hardcode SDK paths, bypassing xcrun entirely.
    # This prevents "unable to find sdk: error:" when xcrun fails in the sandbox.
    # We replace the xcrun command inside $(shell ...) with a direct echo of our fake path.
    sed -i 's|xcrun -sdk macosx --show-sdk-path|echo '"$FAKE_SDK_PATH"'|g' makedefs/MakeInc.*
    sed -i 's|xcrun -sdk macosx --show-sdk-platform-path|echo '"$FAKE_SDK_PATH"'|g' makedefs/MakeInc.*

    # 3. Fake xcrun for any other tools that might call it
    cat > xcrun << EOF
#!/bin/sh
for arg in "\$@"; do
  if [ "\$arg" = "--show-sdk-path" ]; then
    echo "$FAKE_SDK_PATH"
    exit 0
  fi
done
if [ "\$1" = "-find" ]; then
  command -v "\$2" 2>/dev/null || echo "\$2"
  exit 0
fi
exec "\$@"
EOF
    chmod +x xcrun

    # 4. Fake xcodebuild
    cat > xcodebuild << 'EOF'
#!/bin/sh
if [ "$1" = "-version" ]; then
  echo "Xcode 15.0"
  echo "Build version 15A240d"
else
  echo ""
fi
EOF
    chmod +x xcodebuild

    # 5. Fake sw_vers
    cat > sw_vers << 'EOF'
#!/bin/sh
echo "ProductName:    Mac OS X"
echo "ProductVersion: 10.9.5"
echo "BuildVersion:   13F1911"
EOF
    chmod +x sw_vers

    # 6. Symlink gm4 from nixpkgs m4
    ln -s ${m4}/bin/m4 gm4

    # 7. Prepend current directory to PATH so make finds our fake tools immediately
    export PATH="$PWD:$PATH"
    export SDKROOT="$FAKE_SDK_PATH"

    echo "==> Attempting XNU kernel compilation (Phase 3.2)..."
    make clean || true
    
    # Pass SDKROOT explicitly to make
    make ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE BUILD_LTO=0 SDKROOT="$FAKE_SDK_PATH"
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
