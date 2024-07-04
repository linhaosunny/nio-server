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
    /// open WebSocket server
    static func openWebSocketServer(isSSLSecure: Bool = false,
                                    completion: @escaping (_ isSuccess: Bool) -> Void = {_ in }) {
        guard !isServerActive() else {
            stopServer { isSuccess in
                startServer(isSSLSecure: isSSLSecure, completion: completion)
            }
            return
        }
        
        startServer(isSSLSecure: isSSLSecure, completion: completion)
    }
    
    /// close WebSocket server
    static func closeWebSocketServer(completion: @escaping (_ isSuccess: Bool) -> Void = {_ in }) {
        stopServer(completion: completion)
    }
    
    /// server's full url
    static var serverFullUrl: String? {
        guard let host = UIDevice.WIFIIPAddress, let httpServer else { return nil }
        
        let head = httpServer.isSSLSecure ? "wss" : "ws"
        let domain = httpServer.isSSLSecure ? "\(host)" : host
        let port = httpServer.port
        
        return "\(head)://\(domain):\(port)\(serverPath)"
    }
    
    /// server's url
    static var serverUrl: String? {
        guard let host = UIDevice.WIFIIPAddress, let httpServer else { return nil }
        
        let head = httpServer.isSSLSecure ? "wss" : "ws"
        let domain = httpServer.isSSLSecure ? "\(host)" : host
        let port = httpServer.port
        return "\(head)://\(domain):\(port)"
    }
    
    /// server's url path
    static var serverPath: String {
        return "/websocket"
    }
    
}

// MARK: Socket Server
extension LocalHttpServer {
    
    /// http server
    private(set) static var httpServer: NIOHttpServer?
    /// server's work queue
    private static var serverQueue: DispatchQueue = .init(label: "Local.HttpServer.queue")
    /// avalibe ports
    private static let ports: [Int] = [1024, 2048]
    /// port Index
    private static var portIndex: Int = 0
    
    /// Start Server
    /// - Parameter port: port
    /// - Parameter isSSLSecure: SSL Check
    /// - Parameter completion: completion call back
    private static func startServer(isSSLSecure: Bool = false,
                                    port: Int = 1024,
                                    completion: @escaping (_ isSuccess: Bool) -> Void) {
        serverQueue.async {
            let host = UIDevice.WIFIIPAddress ?? "localhost"
            /// configure SSL cert
            let server = NIOHttpServer(host: host, maxFrameSize: 2097152, certificateSSL: isSSLSecure ? .ssl_certificate_pkcs12(file: SSLPKCS12Certificate.file(.server).path ?? "", passphrase: SSLPKCS12Certificate.file(.server).passphrase) : .none)
            self.httpServer = server
            
            /// socket
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
    
    /// stop server
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
    


// MARK: Socket Server Send Message
extension LocalHttpServer {
    
    /// Server's send text
    /// - Parameters:
    ///   - sessionId: connect session id
    ///   - text: content text
    static func serverSend(_ channelId: String, text: String) {
        httpServer?.sendServer(data: .socket_text(channelId: channelId, text: text))
    }

    /// Server's send Data
    /// - Parameters:
    ///   - channelId: connect session id
    ///   - data: data
    static func serverSend(_ channelId: String, data: Data) {
        httpServer?.sendServer(data: .socket_data(channelId: channelId, data: data))
    }
}

// MARK: Socket Server's Notify back
extension LocalHttpServer {
    
    /// Server's Socket notify
    /// - Parameter notify: notify
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

    
    /// client's socke connectt
    /// - Parameter sessionId: connect session Id
    fileprivate static func webSocketConnected(_ sessionId: String) {
        
        /// subect connect
        connectStatusSubject.onNext(.init(sessionId: sessionId, isConnect: true))
        
        
        logger.debug("\r\n Welcome \(sessionId) connect To Server. 🍺🍺🍺.\r\n")
    }
    
    /// client's socke disconnectt
    /// - Parameter sessionId: connect session Id
    fileprivate static func webSocketDisconnected(_ sessionId: String) {
        
        /// subect disconnect
        connectStatusSubject.onNext(.init(sessionId: sessionId, isConnect: false))
    }
    
    
    /// server's receiver client's text
    /// - Parameters:
    ///   - session: session id
    ///   - text: text
    fileprivate static func webSocket(_ sessionId: String, didReceive text: String) {
        
        /// subject text
        receiveSubject.onNext(.init(sessionId: sessionId, content: text))
    
    }
    
    
    /// server's receiver client's data
    /// - Parameters:
    ///   - session: session id
    ///   - text: data
    fileprivate static func webSocket(_ sessionId: String, didReceive data: Data) {
        
        guard let content = String.init(data: data, encoding: .utf8) else {
            return
        }
        
        receiveSubject.onNext(.init(sessionId: sessionId, content: content))
        
    }
}
