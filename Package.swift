// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CustomsToolkit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CustomsToolkit",
            targets: ["CustomsToolkit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CustomsToolkit",
            dependencies: [],
            path: "CustomsToolkit",
            resources: [
                .process("Localization/Resources"),
                .process("Resources"),
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CustomsToolkitTests",
            dependencies: ["CustomsToolkit"],
            path: "CustomsToolkitTests"
        ),
    ]
)
