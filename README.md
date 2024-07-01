# Khan for iOS
[![Build](https://github.com/kibotu/Khan/actions/workflows/build-swift.yml/badge.svg)](https://github.com/kibotu/Khan/actions/workflows/build-swift.yml) [![GitHub Tag](https://img.shields.io/github/v/tag/kibotu/Khan?include_prereleases&sort=semver)](https://github.com/kibotu/Khan/releases) ![Static Badge](https://img.shields.io/badge/Platform%20-%20iOS%20-%20light_green)
[![Static Badge](https://img.shields.io/badge/iOS%20-%20%3E%2016.0%20-%20light_green)](https://support.apple.com/en-us/101566)
[![Static Badge](https://img.shields.io/badge/Swift%205.10%20-%20orange)](https://www.swift.org/blog/swift-5.10-released/)

Khan is a robust dependency management and initialization system for modular app components in Swift.

### Key Features

- Automated dependency resolution and initialization
- Circular dependency detection
- Comprehensive logging for debugging
- Debug mode shuffling to detect order-dependent issues

### Setup

1. Add the Khan framework to your project.
2. Create initializers for your app components:

```swift
class DatabaseInitializer: Initializer {
    static var dependencies: [Initializer.Type] = []
    static func embark() async throws {
        // Initialize database
    }
}
```

### Usage

1. Create a Khan instance with your initializers:

```swift
let initializers: [Initializer.Type] = [
    DatabaseInitializer.self,
    NetworkingInitializer.self,
    // Add other initializers
]

do {
    let khan = try Khan(initializers: initializers)
    try await khan.conquer()
} catch {
    print("Initialization failed: \(error)")
}
```

2. Khan will automatically resolve dependencies and initialize components in the correct order.
   Options

- `enableLogging`: Toggle logging on/off (default: true)

### Advanced Usage

For complex dependency graphs, use `khan.printDependencyTree()` to visualize the initialization order.

## How to install

### Swift Package Manager

Add the dependency to your `Package.swift`

```swift
    products: [
      ...
    ]
    dependencies: [
        .package(url: "https://github.com/kibotu/Khan", from: "1.0.0"),
    ],
    targets: [
      ...
    ]
```

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Swift 5.10 or later

Contributions welcome!

### License
<pre>
Copyright 2024 Jan Rabe & CHECK24

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
</pre>
