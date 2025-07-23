//
//  NetworkPathMonitor.swift
//  NetworkPathMonitor
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.10)
    #error("NetworkPathMonitor doesn't support Swift versions below 5.10")
#endif

import Network

public enum NetworkPathMonitorInfo: Sendable {
    /// Current NetworkPathMonitor version.
    public static let version = "0.2.0"
}

/// A class that monitors network path changes using `NWPathMonitor`.
/// It provides an asynchronous stream of `NWPath` updates.
/// This class is designed to be used in an actor context to ensure thread safety.
public actor NetworkPathMonitor {
    /// The queue on which the network path monitor runs.
    private let monitorQueue: DispatchQueue

    /// Debounce interval in seconds.
    private let debounceInterval: Interval

    /// The network path update handler.
    private var networkPathUpdater: PathUpdateHandler?

    /// The network path monitor.
    private let networkMonitor: NWPathMonitor = .init()

    /// A Boolean value that indicates whether the network path monitor is valid.
    public private(set) var isActive: Bool = false

    /// Task for debouncing path updates.
    private var debounceTask: Task<Void, Never>?

    /// Current network path.
    public private(set) var currentPath: NetworkPath

    /// Network path status change notification.
    public static let networkStatusDidChangeNotification = Notification.Name("NetworkPathMonitor.NetworkPathStatusDidChange")

    /// Initializes a new instance of `NetworkPathMonitor`.
    /// - Parameter queue: The queue on which the network path monitor runs. Default is a serial queue with a unique label.
    /// - Parameter debounceInterval: Debounce interval. If set to 0, no debounce will be applied. Default is 0 seconds.
    public init(queue: DispatchQueue = .init(label: "com.networkPathMonitor.\(UUID())"),
                debounceInterval: Interval = .seconds(0))
    {
        precondition(debounceInterval.nanoseconds >= 0, "debounceInterval must be greater than or equal to 0")
        monitorQueue = queue
        currentPath = NetworkPath(nwPath: networkMonitor.currentPath)
        self.debounceInterval = debounceInterval
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.handlePathUpdate(path) }
        }
    }

    deinit {
        if let debounceTask {
            debounceTask.cancel()
            self.debounceTask = nil
        }
        pathUpdateContinuation = nil
        networkPathUpdater = nil
        networkMonitor.pathUpdateHandler = nil
        networkMonitor.cancel()
    }

    /// Updates the current network path and notifies the handler.
    private var pathUpdateContinuation: AsyncStream<NetworkPath>.Continuation?

    /// An asynchronous stream of network path updates.
    public var pathUpdates: AsyncStream<NetworkPath> {
        AsyncStream { continuation in
            self.pathUpdateContinuation = continuation
            // When the AsyncStream is cancelled, clean up the continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.clearContinuation() }
            }
        }
    }

    private func clearContinuation() {
        pathUpdateContinuation = nil
    }

    private func handlePathUpdate(_ path: NWPath) async {
        var previousPath = currentPath
        // Before yielding, keep the previous sequence
        currentPath = NetworkPath(nwPath: path, sequence: previousPath.sequence)
        // clear previous path avoid infinite reference
        previousPath.clearPreviousPath()

        debounceTask?.cancel()
        guard debounceInterval.nanoseconds > 0 else {
            // No debounce, yield immediately
            debounceTask = nil
            await yieldNetworkPath(previousPath: previousPath)
            return
        }
        // Debounce is active
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(self.debounceInterval.nanoseconds))
                await self.yieldNetworkPath(previousPath: previousPath)
            } catch is CancellationError {
                // Task was cancelled, do nothing
            } catch {
                print("Error during debounce sleep: \(error)")
            }
        }
    }

    // Yield the path update handler
    private func yieldNetworkPath(previousPath: NetworkPath) async {
        // Update sequence
        currentPath.updateSequence(.index(previousPath.sequence.nextIndex, previousPath))

        // Send updates via AsyncStream
        pathUpdateContinuation?.yield(currentPath)

        // Send updates via handler
        Task { await self.networkPathUpdater?(currentPath) }

        // Post network status change notification
        Task {
            NotificationCenter.default.post(
                name: Self.networkStatusDidChangeNotification,
                object: self,
                userInfo: [
                    "newPath": currentPath,
                ]
            )
        }
    }
}

// MARK: - Public API

public extension NetworkPathMonitor {
    /// A type alias for the network path update handler.
    typealias PathUpdateHandler = @Sendable (NetworkPath) async -> Void

    /// Starts monitoring the network path.
    func fire() {
        guard !isActive else { return }
        networkMonitor.start(queue: monitorQueue)
        isActive = true
    }

    /// Stops monitoring the network path.
    func invalidate() {
        guard isActive else { return }
        networkMonitor.cancel()
        isActive = false
    }

    /// A Boolean value indicating whether the network path is satisfied.
    var isPathSatisfied: Bool {
        currentPath.status == .satisfied
    }

    /// Network path status change handler.
    func pathOnChange(_ handler: @escaping PathUpdateHandler) {
        networkPathUpdater = handler
    }
}

// MARK: - Duration Convenience

public extension NetworkPathMonitor {
    enum Interval: Sendable {
        case nanoseconds(_: Int)
        case microseconds(_: Int)
        case milliseconds(_: Int)
        case seconds(_: Double)
        case minutes(_: Int)

        var nanoseconds: Int {
            switch self {
            case let .nanoseconds(value):
                return value
            case let .microseconds(value):
                return value * 1000
            case let .milliseconds(value):
                return value * 1_000_000
            case let .seconds(value):
                return Int(value * 1_000_000_000)
            case let .minutes(value):
                return value * 60 * 1_000_000_000
            }
        }
    }
}
