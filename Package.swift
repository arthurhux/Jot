// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Jot", targets: ["Jot"])],
    targets: [
        .executableTarget(name: "Jot", resources: [.copy("Resources/Editor"), .copy("Resources/Icons")]),
        .testTarget(name: "JotTests", dependencies: ["Jot"])
    ],
    swiftLanguageModes: [.v5]
)
