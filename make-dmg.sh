#!/bin/sh
# Compile Doneko en Release et l'emballe dans build/Doneko.dmg (l'app + un raccourci vers Applications),
# à joindre à une release GitHub. Usage, depuis la racine du projet : ./make-dmg.sh
set -eu
cd "$(dirname "$0")"

xcodegen generate
xcodebuild -project Doneko.xcodeproj -scheme Doneko -configuration Release -derivedDataPath build -quiet build

staging=build/dmg
rm -rf "$staging" build/Doneko.dmg
mkdir -p "$staging"
ditto build/Build/Products/Release/Doneko.app "$staging/Doneko.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname Doneko -srcfolder "$staging" -format UDZO -quiet build/Doneko.dmg
rm -rf "$staging"
echo "build/Doneko.dmg"
