#!/bin/sh
# Compile Doneko en Release et l'emballe dans build/Doneko.dmg, à joindre à une release GitHub : l'app et un raccourci
# vers Applications, sur le fond Artwork/DMGBackground.webp. Usage, depuis la racine du projet : ./make-dmg.sh
# La disposition de la fenêtre est enregistrée par le Finder : macOS demande une fois d'autoriser son contrôle.
set -eu
cd "$(dirname "$0")"
# Le Finder désigne le volume par son nom : un autre « Doneko » ouvert (le DMG publié, par exemple) le tromperait.
volume=/Volumes/Doneko
[ ! -e "$volume" ] || { echo "Éjecte d'abord le volume Doneko." >&2; exit 1; }

xcodegen generate
xcodebuild -project Doneko.xcodeproj -scheme Doneko -configuration Release -derivedDataPath build -quiet build

staging=build/dmg
rm -rf "$staging" build/Doneko.dmg build/Doneko-rw.dmg
mkdir -p "$staging/.background"
ditto build/Build/Products/Release/Doneko.app "$staging/Doneko.app"
ln -s /Applications "$staging/Applications"
swift Artwork/make-dmg-background.swift "$staging/.background"
tiffutil -cathidpicheck "$staging/.background/background.png" "$staging/.background/background@2x.png" \
    -out "$staging/.background/background.tiff"
rm "$staging/.background/background.png" "$staging/.background/background@2x.png"

hdiutil create -volname Doneko -srcfolder "$staging" -format UDRW -quiet build/Doneko-rw.dmg
hdiutil attach -readwrite -noverify -noautoopen -quiet build/Doneko-rw.dmg
trap 'hdiutil detach -quiet "$volume" 2>/dev/null || true' EXIT
# Fenêtre de 660 × 400 pt sous la barre de titre (~32 pt), icônes à la hauteur de la piste de pattes du fond (voir make-dmg-background.swift).
osascript <<'EOF'
tell application "Finder"
    tell disk "Doneko"
        open
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {200, 120, 860, 552}
        end tell
        set options to icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 128
        set text size of options to 13
        set background picture of options to file ".background:background.tiff"
        set position of item "Doneko.app" to {110, 150}
        set position of item "Applications" to {550, 150}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
# Le Finder écrit .DS_Store en différé.
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$volume/.DS_Store" ] && break; sleep 1; done
[ -f "$volume/.DS_Store" ] || { echo "Le Finder n'a pas enregistré la disposition de la fenêtre." >&2; exit 1; }
sync
hdiutil detach -quiet "$volume"
hdiutil convert build/Doneko-rw.dmg -format UDZO -quiet -o build/Doneko.dmg
rm -rf "$staging" build/Doneko-rw.dmg
echo "build/Doneko.dmg"
