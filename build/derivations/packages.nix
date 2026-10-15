# build/derivations/packages.nix — the "shelf": resolve packages/*/manifest.json
# into an install-on-demand catalogue shipped inside the ISO. Binaries are NOT
# baked in (license/provenance gating happens in ../../build/scripts/verify-packages.sh);
# first boot resolves entries against the vendored manifests.
#
# AUDIT FIX (2026-10-15, B12):
#   - Manifests are now passed as an attrset { name = path; }, not a list.
#     The previous `basename $(dirname ${m})` idiom did not survive Nix path
#     interpolation: ${m} expands to /nix/store/<hash>-manifest.json, so
#     dirname → /nix/store, basename → "store", and every manifest was staged
#     as shelf-N-store.json. Consumers in rootfs*.nix glob for *homelab*.json
#     and got nothing, which silently produced "generated 0 launchd plists".
#   - Staged as shelf-<name>.json so source identity survives into the store.
#   - Optionally stages gaming/quiver-defaults.json, which rootfs*.nix copies
#     as ${packages-shelf}/gaming/quiver-defaults.json. When the source file is
#     absent the arg is null and the consumer's guard emits a WARN.
#
# NOTE: the per-app derivations in this directory (whisky/iina/intel-sde/
# tor-browser/lm-studio/mole/davit/antinote/notproton) are deliberately NOT
# referenced here. They carry placeholder fetch hashes and Darwin-only assets;
# they are opt-in on-demand installs handled by scripts/fetch-packages.sh, not
# part of the ISO evaluation path.
{ lib, runCommand, python3, manifests, quiverDefaults ? null }:

runCommand "abzu-packages" {
  nativeBuildInputs = [ python3 ];
  meta.description = "Abzu package shelf (emulators / history-archives / homelab manifests)";
} ''
  set -e
  mkdir -p $out/usr/local/archives/manifests

  # Stage each manifest under its logical name so consumers can glob by source.
  ${lib.concatStrings (lib.mapAttrsToList (name: m: ''
    cp ${m} $out/usr/local/archives/manifests/shelf-${name}.json
  '') manifests)}

  # Phase 5 quiver defaults, consumed by rootfs*.nix at
  # ${packages-shelf}/gaming/quiver-defaults.json.
  ${lib.optionalString (quiverDefaults != null) ''
    mkdir -p $out/gaming
    cp ${quiverDefaults} $out/gaming/quiver-defaults.json
  ''}

  # Sanity: every staged manifest must parse and carry provenance fields —
  # mirrors scripts/verify-packages.sh so `nix flake check` catches drift.
  python3 - "$out" <<'PY'
import json, glob, sys
out = sys.argv[1]
req = ("name","version","source","license","provenance")
n = 0
for f in sorted(glob.glob(out + "/usr/local/archives/manifests/*.json")):
    d = json.load(open(f))
    for p in d.get("packages", []):
        missing = [k for k in req if k not in p]
        assert not missing, f"{f}:{p.get('name')} missing {missing}"
        n += 1
print(f"==> shelf: {n} packages across manifests, all verified")
PY
''
