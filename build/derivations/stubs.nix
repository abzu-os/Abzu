# build/derivations/stubs.nix
# Placeholder payloads for components that cannot be produced without an Apple
# SDK or that are staged out-of-band. Search for "PLACEHOLDER" to find every
# stub that must be replaced with a real artifact before a bootable image is
# shipped.
#
# Consumers:
#   efistub        — mkLinuxSet aliases this to xnu-kernel and passes it as
#                    `kernel` to rootfs.nix. On Linux there is no real XNU, so
#                    this is a marker tree carrying /System and /bootstrap so
#                    rootfs.nix's copy loop has something to copy.
#   phase5-configs — both rootfs.nix and rootfs-slim.nix read
#                    ${phase5-configs}/etc-skel/.config/ and
#                    ${phase5-configs}/stellarium-defaults/config.ini.
#
# The flake merges this attrset with the real openbsd-userland, cuneiform-input,
# gui-core, and packages-shelf derivations, so do NOT add attributes here with
# those names — the merge would silently override them with stale placeholders.
#
# AUDIT NOTE (2026-10-15, B7): this file was referenced by flake.nix's
# mkComponents but absent from the repository. The failure was masked until
# the repoRoot and portability fixes let evaluation reach mkComponents. If a
# canonical stubs.nix exists in git history, prefer restoring it; this is a
# reconstruction based on what the flake and rootfs*.nix actually consume.
{ lib, stdenvNoCC, runCommand }:

rec {
  # efistub — Linux-only placeholder. Real Darwin EFI stubs live in the
  # kernel-* derivations and are consumed by the Darwin set instead. This tree
  # only needs to be a valid store path; rootfs.nix copies it verbatim.
  efistub = runCommand "abzu-efistub-stub" {} ''
    mkdir -p $out/System/Library/Kernels
    echo "PLACEHOLDER efistub — real EFI stub requires a Darwin build" \
      > $out/System/Library/Kernels/kernel
    mkdir -p $out/bootstrap
    echo "PLACEHOLDER bootstrap payload — Darwin build required" \
      > $out/bootstrap/README
  '';

  # phase5-configs — use-case optimization defaults. Real files live in the
  # source tree under userland/ and packages/; this stub provides the minimum
  # layout both rootfs variants cp from so the staging tree builds on any host.
  phase5-configs = runCommand "abzu-phase5-configs-stub" {} ''
    mkdir -p $out/etc-skel/.config
    mkdir -p $out/stellarium-defaults

    # User skeleton configs referenced by rootfs*.nix comments:
    #   vdirsyncer, khal, apple2pi
    cat > $out/etc-skel/.config/vdirsyncer <<'EOF'
# PLACEHOLDER vdirsyncer config — replace with real Phase 5 defaults
[general]
status_path = "~/.vdirsyncer/status/"
EOF

    cat > $out/etc-skel/.config/khal <<'EOF'
# PLACEHOLDER khal config — replace with real Phase 5 defaults
[calendars]
[[home]]
path = ~/.calendars/home/
type = calendar
EOF

    cat > $out/etc-skel/.config/apple2pi <<'EOF'
# PLACEHOLDER apple2pi config — replace with real Phase 5 defaults
EOF

    cat > $out/stellarium-defaults/config.ini <<'EOF'
[main]
# PLACEHOLDER Stellarium defaults — replace with real Phase 5 defaults
EOF
  '';
}
