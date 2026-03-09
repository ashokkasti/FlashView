// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlashView",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlashView", targets: ["FlashView"])
    ],
    targets: [
        .executableTarget(
            name: "FlashView",
            path: "Sources/FlashView",
            exclude: ["Resources"]
        )
    ]
)
