// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EchoCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "EchoCore", targets: ["EchoCore"])],
    targets: [
        .target(name: "EchoCore"),
        .testTarget(name: "EchoCoreTests", dependencies: ["EchoCore"],
                    resources: [.copy("Fixtures")]),
    ]
)
