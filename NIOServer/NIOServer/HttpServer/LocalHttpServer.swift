//
//  LocalServerManager.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//  Local Http Server

import UIKit
import RxSwift
import RxCocoa

class LocalHttpServer: NSObject {
    
    struct SocketServerContextDM: Codable {
        let sessionId: String
        
        let content: String
    }
    
    struct SocketServerStatusDM: Codable {
        let sessionId: String
        
        let isConnect: Bool
    }
    
    /// 连接状态
    static let connectStatusSubject: BehaviorSubject<SocketServerStatusDM?> = .init(value: nil)
    /// 收到文本消息
    static let receiveSubject: BehaviorSubject<SocketServerContextDM?> = .init(value: nil)
    
}
