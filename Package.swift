// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "YabaiBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "YabaiBarCore", targets: ["YabaiBarCore"]),
        .executable(name: "YabaiBar", targets: ["YabaiBar"]),
        .executable(name: "yabai-barctl", targets: ["YabaiBarCLI"]),
    ],
    targets: [
        .target(name: "YabaiBarCore"),
        .executableTarget(name: "YabaiBar", dependencies: ["YabaiBarCore"]),
        .executableTarget(name: "YabaiBarCLI", dependencies: ["YabaiBarCore"]),
        .testTarget(
            name: "YabaiBarCoreTests",
            dependencies: ["YabaiBarCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
