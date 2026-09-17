// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SobeEDesceCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SobeEDesceCore", targets: ["SobeEDesceCore"])
    ],
    targets: [
        .target(name: "SobeEDesceCore"),
        .testTarget(
            name: "SobeEDesceCoreTests",
            dependencies: ["SobeEDesceCore"]
        )
    ]
)
