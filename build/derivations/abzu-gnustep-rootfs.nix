# build/derivations/abzu-gnustep-rootfs.nix
{ pkgs, abzu-init, abzu-wallpapers, gui-core ? null }:

let
  # Use the project's existing gui-core derivation. 
  # If it's somehow null, fall back to a minimal stub structure.
  gnustep-env = if gui-core != null then gui-core else pkgs.runCommand "gnustep-stub" {} ''
    mkdir -p $out/System/GNUstep
    echo "GNUstep stub" > $out/System/GNUstep/README
  '';
in pkgs.runCommand "abzu-gnustep-rootfs" {
  buildInputs = [ gnustep-env ];
} ''
  mkdir -p $out/{sbin,etc/GNUstep/Defaults,Library/Desktop\ Pictures,System/GNUstep}

  # 1. Install the custom Abzu init
  cp ${abzu-init}/sbin/abzu $out/sbin/abzu
  chmod +x $out/sbin/abzu

  # 2. Install the generated wallpapers
  cp -r ${abzu-wallpapers}/Library/Desktop\ Pictures/* "$out/Library/Desktop Pictures/"

  # 3. Assemble the GNUstep environment from the project's gui-core
  if [ -d "${gnustep-env}/System/GNUstep" ]; then
    cp -r --no-preserve=ownership,mode "${gnustep-env}/System/GNUstep/." "$out/System/GNUstep/"
  fi
  chmod -R u+w "$out/System/GNUstep"

  # 4. Create the system-wide GNUstep Defaults (The "Theming" Contract)
  cat > $out/etc/GNUstep/Defaults/.GNUstepDefaults << 'EOF'
{
  GSFontAntiAlias = YES;
  NSInterfaceStyle = metal;
  GSColorOnColor = YES;
  NSWorkspaceDesktopPicture = "/Library/Desktop Pictures/Abzu-abyss.png";
  NSFont = "{Name = Helvetica; Size = 12; }";
  NSBoldFont = "{Name = Helvetica-Bold; Size = 12; }";
}
EOF

  # 5. Create a simple session launcher that /sbin/abzu can call
  cat > $out/sbin/abzu-session << 'EOF'
#!/bin/sh
export GNUSTEP_SYSTEM_ROOT=/System/GNUstep
export GNUSTEP_USER_ROOT=/var/root/GNUstep
export PATH=$GNUSTEP_SYSTEM_ROOT/Local/Tools:$GNUSTEP_SYSTEM_ROOT/System/Tools:$PATH

mkdir -p "$GNUSTEP_USER_ROOT/Defaults"

# Launch GWorkspace (or the project's custom shell)
if [ -x "$GNUSTEP_SYSTEM_ROOT/Local/Tools/GWorkspace" ]; then
  exec openapp GWorkspace
else
  echo "GNUstep environment loaded. Dropping to shell."
  exec /bin/sh
fi
EOF
  chmod +x $out/sbin/abzu-session

  echo "==> Abzu GNUstep Rootfs assembled successfully."
''
