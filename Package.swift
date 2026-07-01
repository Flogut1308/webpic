// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebPic",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WebPicCore"),
        .executableTarget(
            name: "WebPicApp",
            dependencies: ["WebPicCore"]
        ),
        .testTarget(
            name: "WebPicCoreTests",
            dependencies: ["WebPicCore"]
        ),
    ]
)
