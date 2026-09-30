# MacImgViewer

A tiny native macOS image viewer: open an image, zoom with the mouse wheel, flip through the folder with the arrow keys, press Esc to quit.

Built with Swift and AppKit — no dependencies, no Xcode project, a single ~170 KB binary.

## Features

- **Every format macOS can decode** — JPEG, PNG, HEIC/HEIF, AVIF, WebP, JPEG XL, GIF, TIFF, BMP, PSD, ICO, TGA, OpenEXR, JPEG 2000, camera RAW (DNG, CR2/CR3, NEF, ARW, RAF, ORF, RW2…), plus SVG and PDF. The list is read from ImageIO at runtime, so new system codecs are picked up automatically.
- **Screen-fitted window** — sized to the image, shrunk to the screen's usable area (menu bar and Dock excluded), centered. Never upscales.
- **Zoom at the pointer** — mouse wheel zooms around the cursor; trackpad pinch works too.
- **Folder navigation** — ← / → cycle through the other supported images in the same folder, in Finder order, wrapping at the ends.
- **Correct orientation** — EXIF rotation is applied, so phone and camera photos display upright.
- **Animated images** — animated GIF, APNG and WebP play.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode or the Xcode Command Line Tools (Swift 6)

## Installation

```bash
git clone https://github.com/fbanyai/MacImgViewer.git MacImgViewer
cd MacImgViewer
./build.sh --install
```

`build.sh` compiles a release build, assembles `build/MacImgViewer.app`, and ad-hoc signs it. With `--install` it also copies the app to `~/Applications` and registers it with Launch Services; `--set-default` does that and also makes it your default image viewer (see [below](#set-as-default-viewer)). Run `./build.sh` without arguments to build only.

## Usage

```bash
open -a MacImgViewer ~/Pictures/photo.heic
```

Or right-click an image in Finder → **Open With** → **MacImgViewer**. Launching the app with no file shows an Open dialog.

### Controls

| Input | Action |
| ---- | ---- |
| Mouse wheel | Zoom in/out around the pointer |
| Pinch (trackpad) | Zoom in/out |
| Drag | Pan when zoomed in |
| Double-click | Reset zoom to fit |
| ← / → | Previous / next image in the folder |
| Return | Toggle full screen |
| Esc | Exit full screen, or quit |
| ⌘O | Open another file |
| ⌘W / ⌘Q | Quit |

Rolling the wheel away from you always zooms in, regardless of the natural-scrolling setting. Zoom ranges from fit-to-window up to 20×. At 100%, one image pixel equals one physical Retina pixel.

## Set as Default Viewer

For every supported image type at once:

```bash
./build.sh --set-default
```

This installs the app to `~/Applications` and makes it the default for every format ImageIO can decode, plus SVG (61 types on macOS 27). PDFs stay with Preview. It prints a count at the end and exits with an error if any type didn't change.

For a single file type, in Finder: select an image → **Get Info** (⌘I) → **Open with** → **MacImgViewer** → **Change All…**

> `duti -s` does not work for this on recent macOS: it exits cleanly without changing anything. `scripts/set-default.swift` uses `NSWorkspace.setDefaultApplication(at:toOpen:)` instead. `duti -x jpg` still works for checking the result.

## Project Structure

```text
Package.swift                          SwiftPM manifest (macOS 14+, Swift 5 language mode)
build.sh                               Builds and bundles MacImgViewer.app (--install, --set-default)
scripts/set-default.swift              Sets the installed app as default for all supported image types
Resources/Info.plist                   Bundle metadata and document types (public.image, SVG, PDF)
Resources/AppIcon.png                  1024×1024 app icon master (build.sh converts it to .icns)
Sources/MacImgViewer/
  main.swift                           NSApplication bootstrap
  AppDelegate.swift                    File opening (Finder, CLI, Open dialog) and menu
  ViewerWindowController.swift         Window fitting, async loading, key handling
  ZoomScrollView.swift                 Wheel-zoom scroll view, centering clip view, drag-to-pan
  ImageLoader.swift                    ImageIO decoding and supported-format list
  FolderNavigator.swift                Sibling image list and wrap-around stepping
```

## Troubleshooting

- **"MacImgViewer would like to access files in your Downloads folder"** — expected the first time you browse a protected folder (Desktop, Documents, Downloads, external/network volumes). The app lists the folder to enable ← / → navigation.
- **Finder still opens files in the old app** — run `killall Finder`, or re-run `./build.sh --install` if you moved the app.
- **Small images look tiny** — images display at 1 image pixel per Retina pixel. Zoom in with the wheel.

## License

[MIT](LICENSE)
