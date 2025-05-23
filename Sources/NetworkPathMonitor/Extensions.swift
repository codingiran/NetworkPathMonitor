//
//  Extensions.swift
//  NetworkPathMonitor
//
//  Created by CodingIran on 2025/5/21.
//

import Foundation
import Network

// MARK: - Extensions

public extension Network.NWPath {
    var isSatisfied: Bool { status == .satisfied }

    var statusName: String {
        switch status {
        case .satisfied: return "satisfied"
        case .unsatisfied: return "unsatisfied"
        case .requiresConnection: return "requires connection"
        @unknown default: return "unknown"
        }
    }

    @available(macOS 11.0, iOS 14.2, watchOS 7.1, tvOS 14.2, *)
    var unsatisfiedReasonText: String? {
        switch unsatisfiedReason {
        case .notAvailable: return "no specific reason"
        case .cellularDenied: return "user has disabled cellular"
        case .wifiDenied: return "user has disabled wifi"
        case .localNetworkDenied: return "user has disabled local network access"
        case .vpnInactive: return "required VPN is not active"
        @unknown default: return "unknown reason"
        }
    }
}

public extension Network.NWInterface.InterfaceType {
    var name: String {
        switch self {
        case .other: return "other"
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "wiredEthernet"
        case .loopback: return "loopback"
        @unknown default: return "unknown"
        }
    }
}
