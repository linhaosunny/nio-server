//
//  UIDevice+IP.swift
//  NIOServer
//
//  Created by lishaxin on 2024/7/3.
//

import UIKit

extension UIDevice {
    public static var WIFIIPAddress : String? {
         // IPv4
         var address : String?

         // IPv6
         var adds: Set<String> = []

         var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
         if getifaddrs(&ifaddr) == 0 {
              var ptr = ifaddr
              while ptr != nil {
                   defer { ptr = ptr!.pointee.ifa_next }
                   let interface = ptr!.pointee

                   let addrFamily = interface.ifa_addr.pointee.sa_family
                   if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                        let name = String(cString: interface.ifa_name)
                        if name == "en0" || name == "en1" {
                             var addr = interface.ifa_addr.pointee
                             var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                             getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                         &hostname, socklen_t(hostname.count),
                                         nil, socklen_t(0), NI_NUMERICHOST)

                             // IPv4
                             if addrFamily == UInt8(AF_INET) {
                                  address = String(cString: hostname)
                             } else {
                                  let address = String(cString: hostname)
                                  adds.insert(address)
                             }
                             logger.info(String(cString: hostname))
                        }

                   }
              }
              freeifaddrs(ifaddr)
         }

         //        if adds.count != 1 && Int.random(1..<10) % 3 == 0 {
         logger.warning("IPv6 Addrs: ", adds)
         logger.warning("[Use] IPv4 Addrs: ", address ?? "-1")
         //        }
         //        log.info(" getIPv6" , getIPv6())
         return address
    }
}
