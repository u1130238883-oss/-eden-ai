// swift-tools-version:5.9
// NineSun 網頁測試版：把 EchoCore 編成 WebAssembly（和 App 用的是同一份引擎程式碼）
import PackageDescription

let package = Package(
    name: "NineSunWeb",
    dependencies: [.package(path: "../../ios/EchoCore")],
    targets: [
        .executableTarget(
            name: "NineSunWeb",
            dependencies: [.product(name: "EchoCore", package: "EchoCore")],
            linkerSettings: [.unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"])]
        ),
    ]
)
