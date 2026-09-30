# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
./build.sh             # release build → build/MacImgViewer.app (ad-hoc signed)
./build.sh --install   # also copy to ~/Applications and register with Launch Services
swift build            # quick compile check (debug, no .app bundle)
open -a "$PWD/build/MacImgViewer.app" path/to/image.jpg
```

There are no tests or linters. The build should stay warning-free.

Features that depend on the bundle (document types, Finder "Open With", TCC folder prompts) only work from the `.app` that `build.sh` produces, not from `swift run`. `Info.plist` and `AppIcon.png` live in `Resources/`; `build.sh` copies the plist and converts the PNG to `AppIcon.icns` (sips + iconutil). SwiftPM does not process either.

## Architecture

A plain AppKit app built with SwiftPM (tools 6.0, **Swift 5 language mode** to avoid strict-concurrency friction with AppKit). There's no storyboard, nib or Xcode project. `main.swift` bootstraps `NSApplication` by hand, and `AppDelegate` builds the menu in code.

How a file gets opened:
1. `AppDelegate` receives files through `application(_:open:)` (Finder, `open -a`, and argv paths that AppKit forwards). In `applicationDidFinishLaunching` it waits one main-queue turn and only then falls back to CLI args or an `NSOpenPanel`, so files AppKit delivers late aren't opened twice. Cancelling the panel quits the app.
2. There is a single `ViewerWindowController`, reused for every file. `show(url)` creates a `FolderNavigator` and calls `display(url)`.
3. `display` decodes the image on a background queue using `ImageLoader.load`. A `loadToken` counter throws away results that come back out of order when the user presses ←/→ quickly.
4. `apply` sizes the image view, then `fitWindow` resizes and centers the window on the screen's `visibleFrame` and resets the zoom to fit.

Key invariants that span files:
- **Sizing units:** bitmap images are sized as pixels ÷ `backingScaleFactor`, so 100% zoom means one device pixel per image pixel. Vector images (SVG/PDF) keep `NSImage.size` in points. `LoadedImage.isVector` tells the controller which rule to use.
- **Zoom:** this is `NSScrollView` magnification. `ZoomScrollView.scrollWheel` turns wheel input into `setMagnification(_:centeredAt:)`, taking the point in documentView coordinates (they match clip-view bounds coordinates because the document view sits at the origin). `minMagnification` equals the fit scale and is recalculated in `windowDidResize`. `CenteringClipView` centers images smaller than the viewport, and `PanningImageView` handles drag-to-pan and double-click-to-fit.
- **Keys:** Esc and ←/→ are handled by a local `NSEvent` monitor in the controller, not in `keyDown`, because `NSScrollView` would otherwise consume the arrow keys. The monitor only acts on events for its own window, so pressing Esc in the Open panel doesn't quit the app.
- **Formats:** `ImageLoader.supportedContentTypes` comes from `CGImageSourceCopyTypeIdentifiers()` at runtime, plus SVG and PDF. It drives both the Open panel filter and `FolderNavigator`'s extension filter. Don't hard-code format lists. Multi-frame GIF, PNG and WebP load as `NSImage` so they animate; everything else is decoded with `kCGImageSourceCreateThumbnailWithTransform` at full size so EXIF orientation is applied.
- **Navigation:** `FolderNavigator` stores file names, not URLs, sorted with `localizedStandardCompare` (Finder order). It re-lists the folder on every step and copes with the current file having been deleted.

Bundle ID `com.fbanyai.macimgviewer` is referenced in `Resources/Info.plist` and in the README's `duti` instructions; keep them in sync.
