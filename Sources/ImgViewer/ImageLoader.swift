import AppKit
import ImageIO
import UniformTypeIdentifiers

struct LoadedImage {
    let image: NSImage
    /// Pixel dimensions for bitmaps; point dimensions for vector images.
    let size: NSSize
    let isVector: Bool
}

enum ImageLoader {
    /// Everything ImageIO can decode on this macOS version (JPEG, PNG, HEIC, AVIF, WebP, JPEG XL,
    /// GIF, TIFF, BMP, PSD, camera RAW, …) plus the vector formats NSImage renders.
    static let supportedContentTypes: [UTType] = {
        let ids = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
        return ids.compactMap(UTType.init) + [.svg, .pdf]
    }()

    static let supportedExtensions: Set<String> = Set(
        supportedContentTypes.flatMap { $0.tags[.filenameExtension] ?? [] }.map { $0.lowercased() }
    )

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static let animatableTypes: Set<String> = [UTType.gif.identifier, UTType.png.identifier, UTType.webP.identifier]

    static func load(_ url: URL) -> LoadedImage? {
        let ext = url.pathExtension.lowercased()
        if ext == "svg" || ext == "pdf" {
            guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else { return nil }
            return LoadedImage(image: image, size: image.size, isVector: true)
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        // Animated GIF / APNG / WebP: NSImageView animates an NSImage built from the file.
        if CGImageSourceGetCount(source) > 1,
           let type = CGImageSourceGetType(source) as String?, animatableTypes.contains(type),
           let image = NSImage(contentsOf: url),
           let rep = image.representations.first {
            return LoadedImage(image: image, size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh), isVector: false)
        }

        // Decode at full size with the EXIF orientation applied.
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if max(width, height) > 0 { options[kCGImageSourceThumbnailMaxPixelSize] = max(width, height) }

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                ?? CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return LoadedImage(image: NSImage(cgImage: cgImage, size: size), size: size, isVector: false)
    }
}
