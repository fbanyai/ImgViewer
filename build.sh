#!/bin/sh
# Builds build/MacImgViewer.app.
#   --install      also copy it to ~/Applications
#   --set-default  install, then make it the default app for every supported image type
set -eu
cd "$(dirname "$0")"

INSTALL=0
SET_DEFAULT=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --set-default) INSTALL=1; SET_DEFAULT=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

swift build -c release
BIN="$(swift build -c release --show-bin-path)/MacImgViewer"

APP=build/MacImgViewer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacImgViewer"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# AppIcon.png (1024×1024) → AppIcon.icns
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"
codesign --force --sign - "$APP"
echo "Built $APP"

INSTALLED="$HOME/Applications/MacImgViewer.app"
if [ "$INSTALL" = 1 ]; then
    mkdir -p "$HOME/Applications"
    rm -rf "$INSTALLED"
    cp -R "$APP" "$HOME/Applications/"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED"
    echo "Installed to $INSTALLED"
fi

if [ "$SET_DEFAULT" = 1 ]; then
    swift scripts/set-default.swift "$INSTALLED"
fi
