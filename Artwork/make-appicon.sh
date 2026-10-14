#!/bin/sh
# Régénère toutes les tailles de l'AppIcon depuis Artwork/AppIcon.svg, qui découpe Artwork/AppIcon.png
# dans la forme d'icône macOS (nécessite : brew install librsvg).
set -e
cd "$(dirname "$0")/.."
out=Doneko/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p "$out"
images=""
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    file="icon_${size}x${size}@${scale}x.png"
    rsvg-convert -w $px -h $px Artwork/AppIcon.svg -o "$out/$file"
    images="$images    { \"filename\" : \"$file\", \"idiom\" : \"mac\", \"scale\" : \"${scale}x\", \"size\" : \"${size}x${size}\" },
"
  done
done
printf '{\n  "images" : [\n%s  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' "$(printf '%s' "$images" | sed '$ s/,$//')" > "$out/Contents.json"
