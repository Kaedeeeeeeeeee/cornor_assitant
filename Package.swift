// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CornerAssistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CornerAssistant",
            targets: ["CornerAssistant"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CornerAssistant",
            path: "Sources/CornerAssistant",
            resources: [],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
