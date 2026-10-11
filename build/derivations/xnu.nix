# build/derivations/xnu.nix
{ lib, stdenv, stdenvNoCC, clang ? null, llvm ? null, cctools ? null
, xnu-sources ? null, srcInfo, patches ? []
, precompiled ? false
, kernelPath ? "/Users/alinamarsfelder/kernel"
}:

if precompiled then
  stdenvNoCC.mkDerivation rec {
    pname = "xnu-kernel-precompiled";
    version = "10.15.7";

    # builtins.path copies the file into the Nix store and verifies the hash.
    # If the file is missing, Nix will throw a clear OS-level error.
    src = builtins.path {
      path = kernelPath;
      name = "abzu-mach-kernel";
      sha256 = "1lqx1qwnsmzb9cb1gbzlmdaxi565zpk41d51h81zf7hip8rwa6av";
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
