// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DualView",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "dualview", targets: ["dualview"])
    ],
    targets: [
        .target(name: "DualViewCore"),
        .executableTarget(
            name: "dualview",
            dependencies: ["DualViewCore"]
        ),
        .executableTarget(
            name: "dualview-checks",
            dependencies: ["DualViewCore"],
            path: "Checks"
        ),
    ]
)
