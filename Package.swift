// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrowserDaddy",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrowserCore", targets: ["BrowserCore"]),
        .executable(name: "BrowserDaddy", targets: ["BrowserDaddy"]),
    ],
    targets: [
        .target(name: "BrowserCore"),
        .executableTarget(
            name: "BrowserDaddy",
            dependencies: ["BrowserCore"],
            exclude: ["Resources/StorageDaddy.png", "Resources/PageDoodles.png"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "BrowserCoreTests", dependencies: ["BrowserCore"]),
        .testTarget(name: "BrowserDaddyTests", dependencies: ["BrowserDaddy"]),
    ]
)
