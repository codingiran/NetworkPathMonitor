//
//  NetworkPath.swift
//  NetworkPathMonitor
//
//  Created by CodingIran on 2025/7/22.
//

import Foundation
import Network
import NetworkKit

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

    public func usesInterfaceType(_ type: Interface.InterfaceType) -> Bool {
        rawNWPath.usesInterfaceType(type.nwInterfaceType)
    }
}

public extension NetworkPath {
    enum Status: Sendable {
        case unsatisfied
        case satisfied
        case requiresConnection

        init(nwStatus: NWPath.Status) {
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
    enum UnsatisfiedReason: Sendable {
        case cellularDenied
        case localNetworkDenied
        case notAvailable
        case vpnInactive
        case wifiDenied

        init(nwUnsatisfiedReason: NWPath.UnsatisfiedReason) {
            switch nwUnsatisfiedReason {
            case .cellularDenied:
                self = .cellularDenied
            case .localNetworkDenied:
                self = .localNetworkDenied
            case .notAvailable:
                self = .notAvailable
            case .vpnInactive:
                self = .vpnInactive
            case .wifiDenied:
                self = .wifiDenied
            @unknown default:
                fatalError("Unknown NWPath.UnsatisfiedReason value")
            }
        }
    }
}

extension NetworkPath: Equatable, CustomDebugStringConvertible {
    public var debugDescription: String {
        "NetworkPath(status: \(status), availableInterfaces: \(availableInterfaces.map(\.name)), supportsIPv4: \(supportsIPv4), supportsIPv6: \(supportsIPv6), supportsDNS: \(supportsDNS), isConstrained: \(isConstrained), isExpensive: \(isExpensive))"
    }
}
