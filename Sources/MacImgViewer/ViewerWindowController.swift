import AppKit

final class ViewerWindowController: NSWindowController, NSWindowDelegate {
    private let scrollView = ZoomScrollView()
    private let imageView = PanningImageView()
    private let errorLabel = NSTextField(labelWithString: "")
    private var navigator: FolderNavigator?
    private var imageSize = NSSize.zero
    private var loadToken = 0
    private var keyMonitor: Any?

    private static let minContentSize = NSSize(width: 320, height: 240)
    private static let maxMagnification: CGFloat = 20
    private static let wrapSound: NSSound? = {
        let sound = NSSound(named: "Tink")
        sound?.volume = 0.4
        return sound
    }()

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.minContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isRestorable = false
        window.backgroundColor = .black
        window.contentMinSize = Self.minContentSize
        window.collectionBehavior.insert(.fullScreenPrimary)
        super.init(window: window)
        window.delegate = self

        let container = NSView(frame: window.contentLayoutRect)

        scrollView.frame = container.bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.contentView = CenteringClipView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.allowsMagnification = true
        scrollView.maxMagnification = Self.maxMagnification

        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        imageView.isEditable = false
        imageView.onDoubleClick = { [weak self] in self?.zoomToFit() }
        scrollView.documentView = imageView

        errorLabel.textColor = .secondaryLabelColor
        errorLabel.alignment = .center
        errorLabel.isHidden = true
        errorLabel.frame = container.bounds.insetBy(dx: 20, dy: container.bounds.height / 2 - 12)
        errorLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]

        container.addSubview(scrollView)
        container.addSubview(errorLabel)
        window.contentView = container

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            switch event.keyCode {
            case 53: NSApp.terminate(nil)            // Esc
            case 36, 76: self.window?.toggleFullScreen(nil)  // Return, keypad Enter
            case 123: self.navigate(by: -1)          // ←
            case 124: self.navigate(by: 1)           // →
            default: return event
            }
            return nil
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func show(_ url: URL) {
        navigator = FolderNavigator(opening: url)
        display(url)
    }

    private func navigate(by delta: Int) {
        guard let (url, wrapped) = navigator?.step(by: delta) else { return }
        if wrapped { Self.wrapSound?.play() }
        display(url)
    }

    private func display(_ url: URL) {
        loadToken += 1
        let token = loadToken
        updateTitle(for: url)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = ImageLoader.load(url)
            DispatchQueue.main.async { [weak self] in
                guard let self, token == self.loadToken else { return }
                self.apply(loaded, from: url)
            }
        }
    }

    private func updateTitle(for url: URL) {
        guard let window, let navigator else { return }
        let (i, n) = navigator.position
        window.title = "\(url.lastPathComponent)  (\(i)/\(n))"
        window.representedURL = url
    }

    private func apply(_ loaded: LoadedImage?, from url: URL) {
        guard let window else { return }
        let screen = window.isVisible ? (window.screen ?? NSScreen.main) : Self.screenUnderMouse()
        let scale = screen?.backingScaleFactor ?? 2

        if let loaded {
            errorLabel.isHidden = true
            // Bitmaps: 1 image pixel = 1 device pixel at 100%.
            imageSize = loaded.isVector ? loaded.size : NSSize(width: loaded.size.width / scale, height: loaded.size.height / scale)
            imageView.image = loaded.image
        } else {
            errorLabel.stringValue = "Cannot open \(url.lastPathComponent)"
            errorLabel.isHidden = false
            imageSize = .zero
            imageView.image = nil
        }
        imageView.frame = NSRect(origin: .zero, size: imageSize)
        fitWindow(on: screen)
        window.makeKeyAndOrderFront(nil)
    }

    private var isFullScreen: Bool { window?.styleMask.contains(.fullScreen) ?? false }

    /// Sizes the window to the image (shrunk to the screen's usable area, never enlarged) and centers it.
    /// In full screen the window keeps its frame and only the zoom is reset.
    private func fitWindow(on screen: NSScreen?) {
        if isFullScreen { return zoomToFit() }
        guard let window, let screen else { return }
        let visible = screen.visibleFrame
        let maxContent = window.contentRect(forFrameRect: visible).size

        let fit = fitScale(in: maxContent)
        let content = NSSize(
            width: min(maxContent.width, max(Self.minContentSize.width, (imageSize.width * fit).rounded())),
            height: min(maxContent.height, max(Self.minContentSize.height, (imageSize.height * fit).rounded()))
        )
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
        frame.origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
        window.setFrame(frame, display: true)
        zoomToFit()
    }

    private func fitScale(in viewport: NSSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return min(1, viewport.width / imageSize.width, viewport.height / imageSize.height)
    }

    private func zoomToFit() {
        let fit = fitScale(in: scrollView.contentView.frame.size)
        scrollView.minMagnification = fit
        scrollView.magnification = fit
    }

    func windowDidResize(_ notification: Notification) {
        let fit = fitScale(in: scrollView.contentView.frame.size)
        scrollView.minMagnification = fit
        if scrollView.magnification < fit { scrollView.magnification = fit }
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        zoomToFit()
    }

    /// The restored frame belongs to whichever image was showing on entry; refit to the current one.
    func windowDidExitFullScreen(_ notification: Notification) {
        fitWindow(on: window?.screen)
    }

    private static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}
