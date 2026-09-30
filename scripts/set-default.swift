// Makes the given app the default for every image type ImageIO can decode, plus SVG (PDF is left alone).
// Uses NSWorkspace because LSSetDefaultRoleHandlerForContentType (what duti calls) is a silent no-op on recent macOS.
// Usage: swift scripts/set-default.swift ~/Applications/MacImgViewer.app
import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: set-default.swift <path/to/App.app>\n".data(using: .utf8)!)
    exit(2)
}
let app = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath()

// Same source of truth as ImageLoader.supportedContentTypes.
let decodable = (CGImageSourceCopyTypeIdentifiers() as? [String] ?? []).compactMap(UTType.init) + [.svg]
let types = decodable.filter { $0 != .pdf && !($0.tags[.filenameExtension] ?? []).isEmpty }

var failures: [String] = []
for type in types {
    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { error in
        if let error { failures.append("\(type.identifier): \(error.localizedDescription)") }
        done.signal()
    }
    done.wait()
}

for type in types where failures.allSatisfy({ !$0.hasPrefix(type.identifier + ":") }) {
    let handler = NSWorkspace.shared.urlForApplication(toOpen: type)
    if handler?.resolvingSymlinksInPath().path != app.path {
        failures.append("\(type.identifier): still opens in \(handler?.lastPathComponent ?? "nothing")")
    }
}

print("Default app set for \(types.count - failures.count)/\(types.count) image types")
failures.forEach { print("  failed: \($0)") }
exit(failures.isEmpty ? 0 : 1)
