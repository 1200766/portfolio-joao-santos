// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinanceCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FinanceCore", targets: ["FinanceCore"])
    ],
    targets: [
        .target(name: "FinanceCore"),
        .testTarget(name: "FinanceCoreTests", dependencies: ["FinanceCore"])
    ]
)
