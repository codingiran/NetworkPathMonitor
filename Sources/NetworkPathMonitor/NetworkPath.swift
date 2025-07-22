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

    @available(iOS 14.2, macCatalyst 14.2, macOS 11.0, tvOS 14.2, visionOS 1.0, watchOS 7.1, *)
    public var unsatisfiedReason: UnsatisfiedReason? { .init(nwUnsatisfiedReason: rawNWPath.unsatisfiedReason) }

    /// The raw NWPath instance that this NetworkPath wraps.
    public let rawNWPath: NWPath

    public init(nwPath: NWPath) {
        rawNWPath = nwPath
        status = Status(nwStatus: nwPath.status)
        supportsIPv4 = nwPath.supportsIPv4
        supportsIPv6 = nwPath.supportsIPv6
        supportsDNS = nwPath.supportsDNS
        isConstrained = nwPath.isConstrained
        isExpensive = nwPath.isExpensive

        let allInterfaces = NetworkKit.Interface.allInterfaces()
        availableInterfaces = nwPath.availableInterfaces.compactMap { nwInterface in
            guard var interface = allInterfaces.first(where: { $0.name == nwInterface.name }) else { return nil }
            interface.associateNWInterface(nwInterface)
            return interface
        }
    }
}

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

public extension NetworkPath {
    enum Status: Sendable {
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

    @available(iOS 14.2, macCatalyst 14.2, macOS 11.0, tvOS 14.2, visionOS 1.0, watchOS 7.1, *)
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

extension NetworkPath: Equatable, CustomDebugStringConvertible {
    public var debugDescription: String {
        "NetworkPath(status: \(status), availableInterfaces: \(availableInterfaces.map(\.name)), supportsIPv4: \(supportsIPv4), supportsIPv6: \(supportsIPv6), supportsDNS: \(supportsDNS), isConstrained: \(isConstrained), isExpensive: \(isExpensive))"
    }
}
