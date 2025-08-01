# NetworkPathMonitor

[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey.svg)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A modern, type-safe, actor-based network path monitoring utility for Apple platforms.  
NetworkPathMonitor provides an easy and safe way to observe network connectivity changes using Swift Concurrency, AsyncStream, callbacks, and notifications.

> **Need real network connectivity testing?**
Check out [NetworkConnectivityKit](https://github.com/codingiran/NetworkConnectivityKit) - performs actual HTTP requests to detect true internet connectivity, including captive portals.

---

## Features

- 🚦 Real-time network status monitoring based on `NWPathMonitor`
- 🧑‍💻 Actor isolation for thread safety (Swift Concurrency)
- 🌀 AsyncStream support for async/await style observation
- 🛎️ Callback and NotificationCenter support
- ⏳ Debounce mechanism to avoid frequent updates
- 📊 Rich NetworkPath with sequence tracking and update reasons
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
.package(url: "https://github.com/codingiran/NetworkPathMonitor.git", from: "0.1.5")
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
        print("Is first update: \(path.isFirstUpdate)")
        print("Update reason: \(path.updateReason)")
    }
}
```

### Callback

```swift
import NetworkPathMonitor

let monitor = NetworkPathMonitor()
await monitor.pathOnChange { path in
    print("Network changed: \(path.status)")
    print("Is first update: \(path.isFirstUpdate)")
    print("Update reason: \(path.updateReason)")
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
    if let newPath = notification.userInfo?["newPath"] as? NetworkPath {
        print("Network status changed to: \(newPath.status)")
        print("Is first update: \(newPath.isFirstUpdate)")
        print("Update reason: \(newPath.updateReason)")
    }
}
```

---

## Debounce

You can set a debounce interval to avoid frequent updates:

```swift
let monitor = NetworkPathMonitor(debounceInterval: .seconds(1.0)) // 1 second debounce
```

---

## Interval Types

NetworkPathMonitor uses a convenient `Interval` enum for specifying debounce intervals:

```swift
// Different interval types
let monitor1 = NetworkPathMonitor(debounceInterval: .nanoseconds(500_000_000)) // 0.5 seconds
let monitor2 = NetworkPathMonitor(debounceInterval: .milliseconds(500)) // 0.5 seconds
let monitor3 = NetworkPathMonitor(debounceInterval: .seconds(0.5)) // 0.5 seconds
let monitor4 = NetworkPathMonitor(debounceInterval: .minutes(1)) // 1 minute
let monitor5 = NetworkPathMonitor(debounceInterval: .hours(1)) // 1 hour
```

---

## NetworkPath Sequence Tracking

NetworkPathMonitor now provides rich sequence tracking capabilities through the `NetworkPath` type. Each path update includes sequence information and update reasons:

### Sequence Properties

```swift
let monitor = NetworkPathMonitor()
await monitor.fire()

Task {
    for await path in await monitor.pathUpdates {
        // Check if this is the first update after initial connection
        if path.isFirstUpdate {
            print("First network update received")
        }
        
        // Access the previous path for comparison
        if let previousPath = path.sequence.previousPath {
            print("Previous status: \(previousPath.status)")
            print("Previous interfaces: \(previousPath.usedInterfaces.names)")
        }
        
        // Get update reason
        switch path.updateReason {
        case .initial:
            print("Initial path when monitor started")
        case .physicalChange:
            print("Physical network interface changed")
        case .uncertain:
            print("Network status changed for uncertain reason")
        }
    }
}
```

### Update Reasons

- **`.initial`**: The path is the initial path when the monitor is started
- **`.physicalChange`**: The path has changed due to a physical interface change (e.g., switching from WiFi to Cellular)
- **`.uncertain`**: The reason for the update is uncertain (e.g., network configuration changes)

### Sequence Index

Each path update has a sequence index that increments with each update:

```swift
print("Sequence index: \(path.sequence.index)")
print("Is initial path: \(path.sequence.isInitial)")
```

---

## API

### Initialization

```swift
init(queue: DispatchQueue = ..., debounceInterval: Interval = .zero)
```

- `queue`: The dispatch queue for the underlying NWPathMonitor.
- `debounceInterval`: Debounce interval using convenient Interval enum. Default is .zero (no debounce).

### Properties

- `isActive`: Whether monitoring is active.
- `currentPath`: The latest `NetworkPath`.
- `isPathSatisfied`: Whether the current path is satisfied (connected).

### Methods

- `fire()`: Start monitoring.
- `invalidate()`: Stop monitoring.
- `pathOnChange(_:)`: Register a callback for path changes.
- `pathUpdates`: AsyncStream of NetworkPath updates.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Contributing

Contributions are welcome! Please open issues or submit pull requests.

---

## Author

[CodingIran](https://github.com/codingiran)
