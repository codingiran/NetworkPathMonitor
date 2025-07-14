# NetworkPathMonitor

[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey.svg)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A modern, type-safe, actor-based network path monitoring utility for Apple platforms.  
NetworkPathMonitor provides an easy and safe way to observe network connectivity changes using Swift Concurrency, AsyncStream, callbacks, and notifications.

---

## Features

- 🚦 Real-time network status monitoring based on `NWPathMonitor`
- 🧑‍💻 Actor isolation for thread safety (Swift Concurrency)
- 🌀 AsyncStream support for async/await style observation
- 🛎️ Callback and NotificationCenter support
- ⏳ Debounce mechanism to avoid frequent updates
- 🚫 Option to ignore the first path update
- 🛠️ Simple API, easy integration

---

## Requirements

- Swift 5.10 or later
- iOS 13.0+, macOS 10.15+, tvOS 13.0+, watchOS 6.0+, visionOS 1.0+

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
.package(url: "https://github.com/codingiran/NetworkPathMonitor.git", from: "0.0.1")
```

Or use Xcode:  
`File > Add Packages...` and enter the repository URL.

---

## Usage

### Basic Usage

```swift
import NetworkPathMonitor

let monitor = NetworkPathMonitor()
await monitor.fire()

// Check current status
let isConnected = await monitor.isPathSatisfied

// Stop monitoring
await monitor.invalidate()
```

### AsyncStream (Swift Concurrency)

```swift
import NetworkPathMonitor

let monitor = NetworkPathMonitor()
await monitor.fire()

Task {
    for await path in await monitor.pathUpdates {
        print("Network status changed: \(path.status)")
    }
}
```

### Callback

```swift
import NetworkPathMonitor

let monitor = NetworkPathMonitor()
await monitor.pathOnChange { path in
    print("Network changed: \(path.status)")
}
await monitor.fire()
```

### Notification

```swift
import NetworkPathMonitor

let observer = NotificationCenter.default.addObserver(
    forName: NetworkPathMonitor.networkStatusDidChangeNotification,
    object: nil,
    queue: .main
) { notification in
    if let newPath = notification.userInfo?["newPath"] as? NWPath {
        print("Network status changed to: \(newPath.status)")
    }
}
```

---

## Debounce

You can set a debounce interval to avoid frequent updates:

```swift
let monitor = NetworkPathMonitor(debounceInterval: 1.0) // 1 second debounce
```

---

## Ignore First Path Update

Sometimes you may want to ignore the initial network path update that occurs when monitoring starts, especially during app launch. You can use the `ignoreFirstPathUpdate` parameter:

```swift
// Ignore the first path update when monitoring starts
let monitor = NetworkPathMonitor(ignoreFirstPathUpdate: true)
await monitor.fire() // First update will be ignored

// Useful for avoiding immediate notifications during app startup
let monitor = NetworkPathMonitor(
    debounceInterval: 0.5,
    ignoreFirstPathUpdate: true
)
```

This is particularly useful when:

- You want to avoid showing network status alerts immediately when the app starts
- You only care about network changes after the initial connection is established
- You're implementing features that should only respond to actual network transitions

---

## API

### Initialization

```swift
init(queue: DispatchQueue = ..., debounceInterval: TimeInterval = 0, ignoreFirstPathUpdate: Bool = false)
```

- `queue`: The dispatch queue for the underlying NWPathMonitor.
- `debounceInterval`: Debounce interval in seconds. Default is 0 (no debounce).
- `ignoreFirstPathUpdate`: Whether to ignore the first path update. Default is false.

### Properties

- `isActive`: Whether monitoring is active.
- `currentPath`: The latest `NWPath`.
- `isPathSatisfied`: Whether the current path is satisfied (connected).

### Methods

- `fire()`: Start monitoring.
- `invalidate()`: Stop monitoring.
- `pathOnChange(_:)`: Register a callback for path changes.
- `pathUpdates`: AsyncStream of NWPath updates.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Contributing

Contributions are welcome! Please open issues or submit pull requests.

---

## Author

[CodingIran](https://github.com/codingiran)
