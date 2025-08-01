//
//  NetworkPathMonitor.swift
//  NetworkPathMonitor
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
#if compiler(>=6.0)
    public import AsyncTimer
#else
    @_exported import AsyncTimer
#endif

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.10)
    #error("NetworkPathMonitor doesn't support Swift versions below 5.10")
#endif

import Network

public enum NetworkPathMonitorInfo: Sendable {
    /// Current NetworkPathMonitor version.
    public static let version = "0.1.5"
}

/// A class that monitors network path changes using `NWPathMonitor`.
/// It provides an asynchronous stream of `NWPath` updates.
/// This class is designed to be used in an actor context to ensure thread safety.
public actor NetworkPathMonitor {
    /// The queue on which the network path monitor runs.
    private let monitorQueue: DispatchQueue

    /// The debouncer to debounce network path updates.
    private let debouncer: AsyncDebouncer

    /// The network path update handler.
    private var networkPathUpdater: PathUpdateHandler?

    /// The network path monitor.
    private let networkMonitor: NWPathMonitor = .init()

    /// A Boolean value that indicates whether the network path monitor is valid.
    public private(set) var isActive: Bool = false

    /// Current network path.
    public private(set) var currentPath: NetworkPath

    /// Network path status change notification.
    public static let networkStatusDidChangeNotification = Notification.Name("NetworkPathMonitor.NetworkPathStatusDidChange")

    /// Record the previous yield path
    private var previousYieldPath: NetworkPath

    /// Initializes a new instance of `NetworkPathMonitor`.
    /// - Parameter queue: The queue on which the network path monitor runs. Default is a serial queue with a unique label.
    /// - Parameter debounceInterval: Debounce interval. If set to 0, no debounce will be applied. Default is 0 seconds.
    public init(queue: DispatchQueue = .init(label: "com.networkPathMonitor.\(UUID())"),
                debounceInterval: Interval = .zero)
    {
        precondition(debounceInterval.isValid, "debounceInterval must be greater than or equal to 0")
        monitorQueue = queue
        currentPath = NetworkPath(nwPath: networkMonitor.currentPath)
        previousYieldPath = currentPath
        debouncer = AsyncDebouncer(debounceTime: debounceInterval)
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.handlePathUpdate(path) }
        }
    }

    deinit {
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
        // Before yielding, keep the previous sequence
        currentPath = NetworkPath(nwPath: path, sequence: previousYieldPath.sequence)
        // Yield the path by debouncer
        await debouncer.call { [weak self] in
            guard let self else { return }
            await yieldNetworkPath()
        }
    }

    // Yield the path update handler
    private func yieldNetworkPath() async {
        defer {
            // Record the previous yield path
            previousYieldPath = currentPath
        }

        // clear previous path of previous yield path to avoid infinite reference
        previousYieldPath.clearPreviousPath()

        // Update sequence
        currentPath.updateSequence(.index(previousYieldPath.sequence.nextIndex, previousYieldPath))

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
        currentPath.isSatisfied
    }

    /// Network path status change handler.
    func pathOnChange(_ handler: @escaping PathUpdateHandler) {
        networkPathUpdater = handler
    }
}
