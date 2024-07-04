//
//  LocalHttpServer+ServiceNIO.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//  base on SwiftNIO Websocket Server

import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOSSL


extension LocalHttpServer {
    /// 打开WebSocket服务
    static func openWebSocketServer(completion: @escaping (_ isSuccess: Bool) -> Void = {_ in }) {
        guard !isServerActive() else {
            stopServer { isSuccess in
                startServer(completion: completion)
            }
            return
        }
        
        startServer(completion: completion)
    }
    
    /// 关闭WebSocket服务
    static func closeWebSocketServer(completion: @escaping (_ isSuccess: Bool) -> Void = {_ in }) {
        stopServer(completion: completion)
    }
    
    /// 获取服务地址
    static var serverFullUrl: String? {
        guard let host = UIDevice.WIFIIPAddress, let httpServer else { return nil }
        
        let head = httpServer.isSSLSecure ? "wss" : "ws"
        let domain = httpServer.isSSLSecure ? "\(host)" : host
        let port = httpServer.port
        
        return "\(head)://\(domain):\(port)\(serverPath)"
    }
    
    /// 服务器基础地址
    static var serverUrl: String? {
        guard let host = UIDevice.WIFIIPAddress, let httpServer else { return nil }
        
        let head = httpServer.isSSLSecure ? "wss" : "ws"
        let domain = httpServer.isSSLSecure ? "\(host)" : host
        let port = httpServer.port
        return "\(head)://\(domain):\(port)"
    }
    
    /// 服务器路径
    static var serverPath: String {
        return "/websocket"
    }
    
}

// MARK: Socket服务
extension LocalHttpServer {
    
    /// 本地http服务
    private(set) static var httpServer: NIOHttpServer?
    /// 服务器队列
    private static var serverQueue: DispatchQueue = .init(label: "Local.HttpServer.queue")
    /// 可用端口
    private static let ports: [Int] = [1024, 2048]
    /// 端口索引
    private static var portIndex: Int = 0
    /// 启动服务
    /// - Parameter port: 端口
    private static func startServer(port: Int = 1024,
                                    completion: @escaping (_ isSuccess: Bool) -> Void) {
        serverQueue.async {
            let host = UIDevice.WIFIIPAddress ?? "localhost"
            /// 设置SSL证书
            let server = NIOHttpServer(host: host, maxFrameSize: 2097152, certificateSSL: .ssl_certificate_pkcs12_data(bytes: SSLPKCS12Certificate.data(.vibemate).bytes, passphrase: SSLPKCS12Certificate.data(.vibemate).passphrase))
            self.httpServer = server
            
            /// 服务端的socket
            server.socketNotify { notify in
                webSocketNotify(notify)
            }
            
            
            let error = server.start(port: port)

            guard let `error` = error as? NSError else {
                logger.debug("Starting server at port \(port) 🚀.")
                logger.debug("Server Url: \(serverFullUrl ?? "")")
                
                completion(true)
                return
            }
            
            guard error.code == Int(EADDRINUSE) else {
                logger.error("Server start error: \(error)")
                
                completion(false)
                return
            }
            
            portIndex += 1
            guard portIndex < ports.count else {
                portIndex = 0
                logger.error("Server start error: all allow ports is exits")
                completion(false)
                return
            }
            
            let port = ports[portIndex]
            startServer(port: port, completion: completion)
        }
    }
    
    private static func isServerActive() -> Bool {
        return httpServer?.isActive ?? false
    }
    
    /// 停止服务
    private static func stopServer(completion: @escaping (_ isSuccess: Bool) -> Void) {
        serverQueue.async {
            do {
                try httpServer?.stop()
                httpServer = nil
                
                completion(true)
            } catch let error {
                logger.error("Server stop error: \(error)")
                completion(false)
            }
        }
    }
}
    


// MARK: Socket发送消息处理
extension LocalHttpServer {
    
    /// 服务端发送文本
    /// - Parameters:
    ///   - sessionId: 会话id
    ///   - text: 文本
    static func serverSend(_ channelId: String, text: String) {
        httpServer?.sendServer(data: .socket_text(channelId: channelId, text: text))
    }

    /// 服务端发送Data
    /// - Parameters:
    ///   - session: 会话
    static func serverSend(_ channelId: String, data: Data) {
        httpServer?.sendServer(data: .socket_data(channelId: channelId, data: data))
    }
}

// MARK: Socket服务回调
extension LocalHttpServer {
    
    /// 服务器Socket通知
    /// - Parameter notify: 通知
    static func webSocketNotify(_ notify: NIOHttpServer.NIOServerReceiveSocket) {
        switch notify {
        case .connect(let channelId):
            webSocketConnected(channelId)
        case .disconnect(let channelId):
            webSocketDisconnected(channelId)
        case .close(let channelId, let code):
            
            webSocketDisconnected(channelId)
        case .text(let channelId, let text):
            webSocket(channelId, didReceive: text)
        case .data(let channelId, let data):
            webSocket(channelId, didReceive: data)
        }
    }

    
    /// socket连接
    /// - Parameter sessionId: 会话Id
    fileprivate static func webSocketConnected(_ sessionId: String) {
        
        /// 连接通知
        connectStatusSubject.onNext(.init(sessionId: sessionId, isConnect: true))
        
        
        logger.debug("\r\n Welcome \(sessionId) connect To Server. 🍺🍺🍺.\r\n")
    }
    
    /// socket断开连接
    /// - Parameter session: 会话
    fileprivate static func webSocketDisconnected(_ sessionId: String) {
        
        /// 断开连接
        connectStatusSubject.onNext(.init(sessionId: sessionId, isConnect: false))
    }
    
    
    /// socket收到文本消息
    /// - Parameters:
    ///   - session: 会话
    ///   - text: 文本
    fileprivate static func webSocket(_ sessionId: String, didReceive text: String) {
        
        /// 接收到文本内容
        receiveSubject.onNext(.init(sessionId: sessionId, content: text))
    
    }
    
    
    /// 收到二进制数据
    /// - Parameters:
    ///   - session: 会话
    ///   - data: 数据
    fileprivate static func webSocket(_ sessionId: String, didReceive data: Data) {
        // 接收消息
        
        guard let content = String.init(data: data, encoding: .utf8) else {
            return
        }
        
        receiveSubject.onNext(.init(sessionId: sessionId, content: content))
        
    }
}
