# build/derivations/xnu.nix
{ lib, stdenv, stdenvNoCC, fetchurl, clang ? null, llvm ? null, cctools ? null
, xnu-sources ? null, srcInfo, patches ? []
, precompiled ? false
, kernelPath ? "/Users/alinamarsfelder/Abzu-Kernels/kernel"
}:

if precompiled then
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "10.15.7";

    # fetchurl with file:// is the correct way to fetch a local file with a hash.
    # The --impure flag allows it to read paths outside the Nix store.
    src = fetchurl {
      url = "file://${kernelPath}";
      hash = "sha256-WxnFM7oRHvcDgqG0QOb9xZTYVav0rxcWS+tXbTkOHdM=";
    };

    phases = [ "installPhase" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/System/Library/Kernels"
      cp "$src" "$out/System/Library/Kernels/kernel"
      chmod 644 "$out/System/Library/Kernels/kernel"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Pre-compiled x86_64 XNU Kernel (from local Intel Mac)";
      platforms = [ "x86_64-darwin" "x86_64-linux" "aarch64-darwin" "aarch64-linux" ];
    };
  }
else
  stdenv.mkDerivation rec {
    pname = "xnu-kernel";
    version = srcInfo.xnuTag;

    src = xnu-sources;
    sourceRoot = "abzu-xnu-sources-${srcInfo.xnuTag}/xnu";
    nativeBuildInputs = [ clang llvm cctools ];

    patchPhase = ''
      runHook prePatch
      for p in ${lib.concatMapStringsSep " " (x: ''"${x}"'') patches}; do
        echo "applying kernel patch: $p"
        git apply --whitespace=nowarn "$p"
      done
      runHook postPatch
    '';

    buildPhase = ''
      runHook preBuild
      make SDKROOT=macosx \
           ARCH_CONFIGS=X86_64 \
           KERNEL_CONFIGS=RELEASE \
           TARGET_CONFIGS=X86_64 \
           -j $NIX_BUILD_CORES
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/System/Library/Kernels
      cp BUILD/obj/RELEASE_X86_64/mach_kernel $out/System/Library/Kernels/kernel
      cp -r BUILD/obj/RELEASE_X86_64/mach_kernel.dSYM $out/System/Library/Kernels/ || true
      runHook postInstall
    '';

    meta = with lib; {
      description = "Apple XNU kernel compiled from source";
      homepage = "https://opensource.apple.com/source/xnu/";
      license = licenses.apsl20;
      platforms = [ "x86_64-darwin" ];
    };
  }
