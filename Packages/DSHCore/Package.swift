// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DSHCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DSHCore", targets: ["DSHCore"])],
    targets: [
        .target(name: "DSHCore"),
        .testTarget(name: "DSHCoreTests", dependencies: ["DSHCore"], resources: [.copy("Fixtures")])
    ]
)
