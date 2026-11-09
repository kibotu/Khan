// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Khan",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Khan", targets: ["Khan"]),
    ],
    targets: [
        .target(name: "Khan"),
        .testTarget(name: "KhanTests", dependencies: ["Khan"]),
    ]
)
