// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacImgViewer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacImgViewer",
            path: "Sources/MacImgViewer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
