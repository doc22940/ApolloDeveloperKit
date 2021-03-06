//
//  NetworkInterface.swift
//  ApolloDeveloperKit
//
//  Created by Ryosuke Ito on 8/18/19.
//  Copyright © 2019 Ryosuke Ito. All rights reserved.
//

import Darwin

/**
 * `NetworkInterface` is a Swift bridge for Unix `ifaddrs`.
 */
struct NetworkInterface {
    /**
     * Name of this interface.
     */
    let name: String
    private let addressPointer: UnsafeMutablePointer<sockaddr>
    private let flags: UInt32

    /**
     * Boolean value representing whether if this interface is up or down.
     */
    var isUp: Bool {
        return (flags & UInt32(IFF_UP)) == 1
    }

    /**
     * Socket family of this interface.
     */
    var socketFamily: sa_family_t {
        return addressPointer.pointee.sa_family
    }

    /**
     * IPv4 address tied up with this interface.
     */
    var ipv4Address: String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(addressPointer,
                          socklen_t(addressPointer.pointee.sa_len),
                          &host,
                          socklen_t(host.count),
                          nil,
                          0,
                          NI_NUMERICHOST | NI_NOFQDN) == 0 else {
            return nil
        }
        return String(cString: host, encoding: .ascii)
    }

    init(addr: ifaddrs) {
        self.name = String(cString: addr.ifa_name)
        self.flags = addr.ifa_flags
        self.addressPointer = addr.ifa_addr
    }
}
