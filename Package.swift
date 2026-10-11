// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TermPaste",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TermPaste", targets: ["TermPaste"])],
    targets: [
        .target(name: "PasteRouting"),
        .executableTarget(name: "TermPaste", dependencies: ["PasteRouting"]),
        .testTarget(name: "PasteRoutingTests", dependencies: ["PasteRouting"]),
    ],
    swiftLanguageModes: [.v5]
)
