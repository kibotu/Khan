# Khan for iOS
[![Build](https://github.com/kibotu/Khan/actions/workflows/build-swift.yml/badge.svg)](https://github.com/kibotu/Khan/actions/workflows/build-swift.yml) [![GitHub Tag](https://img.shields.io/github/v/tag/kibotu/Khan?include_prereleases&sort=semver)](https://github.com/kibotu/Khan/releases) ![Static Badge](https://img.shields.io/badge/Platform%20-%20iOS%20-%20light_green)
[![Static Badge](https://img.shields.io/badge/iOS%20-%20%3E%2016.0%20-%20light_green)](https://support.apple.com/en-us/101566)
[![Static Badge](https://img.shields.io/badge/Swift%206%20-%20orange)](https://www.swift.org/blog/swift-6-released/)

Khan starts your app's modules in parallel while guaranteeing that every initializer runs only after the ones it depends on.

### Key Features

- Parallel start-up: each initializer launches the moment its dependencies succeed
- Graph validated up front: missing dependencies and cycles (with the full path) throw from `init`
- Failure isolation: if an initializer throws, its dependents are skipped, everything else still runs
- Swift concurrency native, `@MainActor` friendly, optional logging hook

### Usage

```swift
enum ConfigInitializer: Initializer {
    static func embark() async throws { /* load config */ }
}

enum DatabaseInitializer: Initializer {
    static let dependencies: [Initializer.Type] = [ConfigInitializer.self]

    @MainActor static func embark() async throws { /* open database */ }
}

let khan = try Khan(
    initializers: [ConfigInitializer.self, DatabaseInitializer.self],
    logger: { print("[Khan]", $0) }
)
try await khan.conquer()
```

Every dependency must be registered too, otherwise `Khan.init` throws `KhanError.missingDependency`.

### Errors

`conquer()` throws `KhanError.failed(_:skipped:)` after all runnable work has settled. It lists each failed initializer with its error, and the initializers that never ran because a dependency failed.

## How to install

### Swift Package Manager

Add the dependency to your `Package.swift`

```swift
    products: [
      ...
    ]
    dependencies: [
        .package(url: "https://github.com/kibotu/Khan", from: "<version>"),
    ],
    targets: [
      ...
    ]
```

## Requirements

- iOS 16.0 or later (macOS 13 for running the tests)
- Xcode 16.0 or later
- Swift 6.0 or later

Contributions welcome!
