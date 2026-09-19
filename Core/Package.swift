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
        .library(name: "PETCategorization", targets: ["PETCategorization"]),
        .library(name: "PETRepositories", targets: ["PETRepositories"]),
        .library(name: "PETSharedUI", targets: ["PETSharedUI"]),
    ],
    targets: [
        .target(
            name: "PETModels",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PETCategorization",
            dependencies: ["PETModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PETRepositories",
            dependencies: ["PETModels", "PETCategorization"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PETSharedUI",
            dependencies: ["PETModels", "PETRepositories"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PETModelsTests",
            dependencies: ["PETModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PETCategorizationTests",
            dependencies: ["PETCategorization"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PETRepositoriesTests",
            dependencies: ["PETRepositories"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
