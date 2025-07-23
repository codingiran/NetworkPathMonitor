//
//  NetworkPath.swift
//  NetworkPathMonitor
//
//  Created by CodingIran on 2025/7/22.
//

import Foundation
import Network

#if compiler(>=6.0)
    public import NetworkKit
#else
    @_exported import NetworkKit
#endif

public struct NetworkPath: Sendable {
    /// A status indicating whether a path can be used by connections.
    public let status: Status

    /// A list of all interfaces available to the path, in order of preference.
    public let availableInterfaces: [NetworkKit.Interface]

    /// A Boolean indicating whether the path can route IPv4 traffic.
    public let supportsIPv4: Bool

    /// A Boolean indicating whether the path can route IPv6 traffic.
    public let supportsIPv6: Bool

    /// A Boolean indicating whether the path has a DNS server configured.
    public let supportsDNS: Bool

    /// A Boolean indicating whether the path uses an interface in Low Data Mode.
    public let isConstrained: Bool

    /// A Boolean indicating whether the path uses an interface that is considered expensive, such as Cellular or a Personal Hotspot.
    public let isExpensive: Bool

    /// A Boolean indicating whether the path is satisfied.
    public var isSatisfied: Bool { status == .satisfied }

    @available(iOS 14.2, macCatalyst 14.2, macOS 11.0, tvOS 14.2, visionOS 1.0, watchOS 7.1, *)
    public var unsatisfiedReason: UnsatisfiedReason? { .init(nwUnsatisfiedReason: rawNWPath.unsatisfiedReason) }

    /// The raw NWPath instance that this NetworkPath wraps.
    public let rawNWPath: NWPath

    /// An enum indicating the sequence of update.
    /// It only grow when the path update triggered.
    public private(set) var sequence: Sequence

    public init(nwPath: NWPath, sequence: Sequence = .initial) {
        rawNWPath = nwPath
        status = Status(nwStatus: nwPath.status)
        supportsIPv4 = nwPath.supportsIPv4
        supportsIPv6 = nwPath.supportsIPv6
        supportsDNS = nwPath.supportsDNS
        isConstrained = nwPath.isConstrained
        isExpensive = nwPath.isExpensive
        availableInterfaces = nwPath.availableInterfaces.compactMap { nwInterface in
            guard var interface = NetworkKit.Interface.interfaces(matching: { $0 == nwInterface.name }).first else { return nil }
            interface.associateNWInterface(nwInterface)
            return interface
        }
        self.sequence = sequence
    }
}

// MARK: - Interface

public extension NetworkPath {
    /// Network interfaces used by this path
    var usedInterfaces: [NetworkKit.Interface] {
        availableInterfaces.filter { usesInterfaceType($0.type) }
    }

    /// Physical network interfaces used by this path, excluding virtual interfaces
    var usedPhysicalInterfaces: [NetworkKit.Interface] {
        usedInterfaces.filter {
            switch $0.type {
            case .wifi, .cellular, .wiredEthernet: return true
            default: return false
            }
        }
    }

    /// The primary used physical network interface, which is the first in the list of used interfaces
    var primaryUsedPhysicalInterface: NetworkKit.Interface? { usedInterfaces.first }

    /// Checks if the path uses an NWInterface with the specified type
    func usesInterfaceType(_ type: Interface.InterfaceType) -> Bool {
        rawNWPath.usesInterfaceType(type.nwInterfaceType)
    }
}

// MARK: - Status

public extension NetworkPath {
    enum Status: Sendable, Equatable {
        /// The path has a usable route upon which to send and receive data
        case satisfied

        /// The path does not have a usable route. This may be due to a network interface being down, or due to system policy.
        case unsatisfied

        /// The path does not currently have a usable route, but a connection attempt will trigger network attachment.
        case requiresConnection

        /// Initializes a Status from a NWPath.Status
        fileprivate init(nwStatus: NWPath.Status) {
            switch nwStatus {
            case .satisfied:
                self = .satisfied
            case .unsatisfied:
                self = .unsatisfied
            case .requiresConnection:
                self = .requiresConnection
            @unknown default:
                fatalError("Unknown NWPath.Status value")
            }
        }
    }
}

// MARK: - UnsatisfiedReason

@available(iOS 14.2, macCatalyst 14.2, macOS 11.0, tvOS 14.2, visionOS 1.0, watchOS 7.1, *)
public extension NetworkPath {
    enum UnsatisfiedReason: Sendable, CustomStringConvertible {
        /// No reason is given
        case notAvailable

        /// The user has disabled cellular
        case cellularDenied

        /// The user has disabled Wi-Fi
        case wifiDenied

        /// The user has disabled local network access
        case localNetworkDenied

        /// A required VPN is not active
        @available(macOS 14.0, iOS 17.0, macCatalyst 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
        case vpnInactive

        /// Initializes an UnsatisfiedReason from a NWPath.UnsatisfiedReason
        fileprivate init(nwUnsatisfiedReason: NWPath.UnsatisfiedReason) {
            switch nwUnsatisfiedReason {
            case .notAvailable:
                self = .notAvailable
            case .cellularDenied:
                self = .cellularDenied
            case .wifiDenied:
                self = .wifiDenied
            case .localNetworkDenied:
                self = .localNetworkDenied
            case .vpnInactive:
                if #available(macOS 14.0, iOS 17.0, macCatalyst 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *) {
                    self = .vpnInactive
                }
            @unknown default:
                fatalError("Unknown NWPath.UnsatisfiedReason value")
            }
            self = .notAvailable
        }

        public var description: String {
            switch self {
            case .cellularDenied: return "Cellular access denied"
            case .localNetworkDenied: return "Local network access denied"
            case .notAvailable: return "Network not available"
            case .vpnInactive: return "VPN is inactive"
            case .wifiDenied: return "WiFi access denied"
            }
        }
    }
}

// MARK: - Sequence

public extension NetworkPath {
    /// An enum representing the sequence of updates for a NetworkPath.
    /// Using an enum for indirect recursion: https://forums.swift.org/t/using-indirect-modifier-for-struct-properties/37600/14
    indirect enum Sequence: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        /// An update triggered by the `pathUpdateHandler` closure of `NWPathMonitor`
        case index(_ index: Int, _ previousPath: NetworkPath?)

        /// Convenience initializer for the initial sequence
        public static let initial = Sequence.index(0, nil)

        /// The previous path in the sequence, if it exists
        var previousPath: NetworkPath? {
            switch self {
            case let .index(_, previousPath): return previousPath
            }
        }

        /// Indicates whether this is the initial path in the sequence
        var isInitial: Bool { index == 0 }

        /// Indicates whether this is the first update in the sequence
        var isFirstUpdate: Bool { index == 1 }

        /// The current index of this sequence update, if it exists
        var index: Int {
            switch self {
            case let .index(value, _): return value
            }
        }

        /// The next index in the sequence, which is one greater than the current index
        var nextIndex: Int { index + 1 }

        public var description: String { debugDescription }

        public var debugDescription: String {
            switch self {
            case let .index(index, _): return "index(\(index))"
            }
        }
    }

    /// Updates the sequence
    mutating func updateSequence(_ sequence: Sequence) {
        self.sequence = sequence
    }

    /// Clears the previous path
    mutating func clearPreviousPath() {
        sequence = .index(sequence.index, nil)
    }
}

// MARK: - UpdateReason

public extension NetworkPath {
    enum UpdateReason: Sendable, Equatable {
        /// The path is the initial path when the `NWPathMonitor` is started
        case initial
        /// The path has changed due to a physical interface change
        case physicalChange
        /// The reason for the update is uncertain
        case uncertain

        /// Indicates whether this is the initial path.
        var isInitial: Bool {
            switch self {
            case .initial:
                return true
            default:
                return false
            }
        }

        /// Indicates whether this is a physical interface change.
        var isPhysicalChange: Bool {
            switch self {
            case .physicalChange:
                return true
            default:
                return false
            }
        }
    }

    /// An enum indicating the reason of update.
    var updateReason: UpdateReason {
        if sequence.isInitial {
            // The initial path is created when the `NWPathMonitor` is started
            return .initial
        }
        let previousUsedPhysicalInterfaces = sequence.previousPath?.usedPhysicalInterfaces
        guard previousUsedPhysicalInterfaces == usedPhysicalInterfaces else {
            // If the used physical interfaces have changed, it indicates a physical interface change
            return .physicalChange
        }
        return .uncertain
    }
}

// MARK: - Diffrence

private extension NetworkPath {
    private struct Difference: Sendable {
        let isInitial: Bool
        let pyhicalChange: Bool
        let stausChange: Bool
        let rawNWPathChange: Bool
    }

    private func diff(from previousPath: NetworkPath?) -> Difference {
        let isInitial = previousPath == nil || sequence.index == 0
        let pyhicalChange = previousPath?.usedPhysicalInterfaces != usedPhysicalInterfaces
        let stausChange = previousPath?.status != status
        let rawNWPathChange = previousPath?.rawNWPath != rawNWPath
        return .init(isInitial: isInitial, pyhicalChange: pyhicalChange, stausChange: stausChange, rawNWPathChange: rawNWPathChange)
    }
}

// MARK: - Equatable & CustomStringConvertible

extension NetworkPath: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "NetworkPath(status: \(status), availableInterfaces: \(availableInterfaces.map(\.name))"
    }

    public var debugDescription: String {
        "NetworkPath(status: \(status), availableInterfaces: \(availableInterfaces.map(\.name)), supportsIPv4: \(supportsIPv4), supportsIPv6: \(supportsIPv6), supportsDNS: \(supportsDNS), isConstrained: \(isConstrained), isExpensive: \(isExpensive)), isSatisfied: \(isSatisfied)), sequence: \(sequence.debugDescription), previousSequence: \(sequence.previousPath?.sequence.debugDescription ?? "null")"
    }
}
