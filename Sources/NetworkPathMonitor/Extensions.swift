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
}
