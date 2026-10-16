# build/derivations/abzu-gnustep-rootfs.nix
{ pkgs, abzu-init, abzu-wallpapers }:

let
  # We use the standard Nixpkgs GNUstep packages for stability
  gnustep-pkgs = with pkgs.gnustep; [
    make
    base
    gui
    back
    workspace # GWorkspace (the Finder equivalent)
    systemprefs
    terminal
  ];
in pkgs.runCommand "abzu-gnustep-rootfs" {
  # Ensure all GNUstep dependencies are in the closure
  buildInputs = gnustep-pkgs;
} ''
  mkdir -p $out/{sbin,etc/GNUstep/Defaults,Library/Desktop\ Pictures,System/GNUstep}

  # 1. Install the custom Abzu init
  cp ${abzu-init}/sbin/abzu $out/sbin/abzu
  chmod +x $out/sbin/abzu

  # 2. Install the generated wallpapers
  cp -r ${abzu-wallpapers}/Library/Desktop\ Pictures/* "$out/Library/Desktop Pictures/"

  # 3. Assemble the GNUstep environment
  # We copy the Nix store GNUstep paths into a unified System/GNUstep directory
  # so the kernel's init can find them predictably at /System/GNUstep
  for pkg in ${builtins.concatStringsSep " " gnustep-pkgs}; do
    if [ -d "$pkg/GNUstep" ]; then
      cp -r --no-preserve=ownership,mode "$pkg/GNUstep/." "$out/System/GNUstep/"
    fi
  done
  chmod -R u+w "$out/System/GNUstep"

  # 4. Create the system-wide GNUstep Defaults (The "Theming" Contract)
  # This replicates the GSettings overrides from Abyssolith, but for GNUstep's native XML format
  cat > $out/etc/GNUstep/Defaults/.GNUstepDefaults << 'EOF'
{
  GSFontAntiAlias = YES;
  NSInterfaceStyle = metal; /* Gives a more modern, less gray look */
  GSColorOnColor = YES;
  NSWorkspaceDesktopPicture = "/Library/Desktop Pictures/Abzu-abyss.png";
  NSFont = "{Name = Helvetica; Size = 12; }";
  NSBoldFont = "{Name = Helvetica-Bold; Size = 12; }";
}
EOF

  # 5. Create a simple session launcher that /sbin/abzu can call
  # This sets up the GNUstep environment variables and launches the Workspace Manager
  cat > $out/sbin/abzu-session << 'EOF'
#!/bin/sh
export GNUSTEP_SYSTEM_ROOT=/System/GNUstep
export GNUSTEP_USER_ROOT=/var/root/GNUstep
export PATH=$GNUSTEP_SYSTEM_ROOT/Local/Tools:$GNUSTEP_SYSTEM_ROOT/System/Tools:$PATH

# Ensure user defaults directory exists
mkdir -p "$GNUSTEP_USER_ROOT/Defaults"

# Launch GWorkspace (the GNUstep desktop environment)
exec openapp GWorkspace
EOF
  chmod +x $out/sbin/abzu-session

  echo "==> Abzu GNUstep Rootfs assembled successfully."
''
