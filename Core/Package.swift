// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PETCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PETModels", targets: ["PETModels"]),
    ],
    targets: [
        .target(
            name: "PETModels",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PETModelsTests",
            dependencies: ["PETModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
