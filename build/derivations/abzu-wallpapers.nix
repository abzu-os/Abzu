# build/derivations/abzu-wallpapers.nix
{ pkgs }:

pkgs.runCommand "abzu-wallpapers" {
  nativeBuildInputs = [ pkgs.imagemagick ];
} ''
  mkdir -p "$out/Library/Desktop Pictures"
  
  # Generate Abzu Abyss (Teal/Deep Blue radial gradient)
  # Using 1024x768 for QEMU-PPC compatibility, easily scalable later
  convert -size 1024x768 radial-gradient:'#0b6e8f-#041e2c' \
    "$out/Library/Desktop Pictures/Abzu-abyss.png"
    
  # Generate Abzu Deep (Darker radial gradient)
  convert -size 1024x768 radial-gradient:'#123c5e-#02090f' \
    "$out/Library/Desktop Pictures/Abzu-deep.png"
''
