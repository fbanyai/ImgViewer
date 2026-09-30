import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: ViewerWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.mainMenu = buildMenu()
        NSApp.activate()

        // Finder / `open -a` deliver files through application(_:open:), which may arrive
        // right after launch — defer so we only fall back when nothing was opened.
        DispatchQueue.main.async { [self] in
            guard controller == nil else { return }
            let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
            if let path = paths.first {
                show(URL(fileURLWithPath: path))
            } else if !runOpenPanel() {
                NSApp.terminate(nil)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { show(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func show(_ url: URL) {
        let controller = self.controller ?? ViewerWindowController()
        self.controller = controller
        controller.show(url)
    }

    /// Returns false when the user cancels.
    @discardableResult
    private func runOpenPanel() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ImageLoader.supportedContentTypes
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        show(url)
        return true
    }

    @objc private func openDocument(_ sender: Any?) {
        runOpenPanel()
    }

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit ImgViewer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o").target = self
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = fileMenu

        return main
    }
}
