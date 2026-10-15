// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Holdlet",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Holdlet", targets: ["HoldletApp"]), .library(name: "HoldletCore", targets: ["HoldletCore"])],
    targets: [
        .target(name: "HoldletCore"),
        .executableTarget(name: "HoldletApp", dependencies: ["HoldletCore"]),
        .testTarget(name: "HoldletCoreTests", dependencies: ["HoldletCore"]),
        .testTarget(name: "HoldletAppTests", dependencies: ["HoldletApp", "HoldletCore"])
    ],
    swiftLanguageModes: [.v5]
)
