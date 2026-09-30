// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PopAMCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PopAMCore", targets: ["PopAMCore"])],
    targets: [
        .target(name: "PopAMCore"),
        .testTarget(name: "PopAMCoreTests", dependencies: ["PopAMCore"]),
    ]
)
