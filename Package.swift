// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebPic",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "WebPicCore",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode"),
            ]
        ),
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
