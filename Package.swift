// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Khan",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Khan", targets: ["Khan"]),
    ],
    targets: [
        .target(name: "Khan"),
        .testTarget(name: "KhanTests", dependencies: ["Khan"]),
    ]
)
