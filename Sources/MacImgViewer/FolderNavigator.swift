import Foundation

/// Tracks the supported images in the current file's folder, sorted like Finder.
struct FolderNavigator {
    private var directory: URL
    private var names: [String]
    private var index: Int

    var current: URL { directory.appendingPathComponent(names[index]) }
    var position: (index: Int, count: Int) { (index + 1, names.count) }

    init(opening url: URL) {
        directory = url.deletingLastPathComponent()
        names = Self.imageNames(in: directory)
        let name = url.lastPathComponent
        if let i = names.firstIndex(of: name) {
            index = i
        } else {
            // Opened a file we don't list (e.g. unusual extension): keep it in the sequence.
            index = Self.insertionIndex(of: name, in: names)
            names.insert(name, at: index)
        }
    }

    /// Moves by `delta`, wrapping past either end (`wrapped` reports it). Re-lists the folder so added/removed files are picked up.
    mutating func step(by delta: Int) -> (url: URL, wrapped: Bool)? {
        let currentName = names[index]
        let fresh = Self.imageNames(in: directory)
        guard !fresh.isEmpty else { return nil }

        let base: Int
        if let i = fresh.firstIndex(of: currentName) {
            base = i
        } else {
            // Current file vanished: step relative to where it used to sit.
            let insertion = Self.insertionIndex(of: currentName, in: fresh)
            base = delta > 0 ? insertion - 1 : insertion
        }
        names = fresh
        let target = base + delta
        index = (target % names.count + names.count) % names.count
        return (current, !names.indices.contains(target))
    }

    private static func imageNames(in directory: URL) -> [String] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { ImageLoader.isSupported($0) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func insertionIndex(of name: String, in names: [String]) -> Int {
        names.firstIndex { $0.localizedStandardCompare(name) == .orderedDescending } ?? names.count
    }
}
