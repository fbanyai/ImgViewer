// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ImgViewer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ImgViewer",
            path: "Sources/ImgViewer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
