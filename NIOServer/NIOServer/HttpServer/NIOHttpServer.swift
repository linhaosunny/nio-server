//
//  NIOHttpServer.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//  base on SwiftNIO Websocket Server

import UIKit
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import NIOSSL

/// SwiftNIO 服务
class NIOHttpServer {
    
    /// The server's port.
    var port: Int {
        return channel?.localAddress?.port ?? _port
    }
    
    /// The server's path
    var path: String {
        return channel?.localAddress?.pathname ?? "websocket"
    }
    
    /// isOpenSSL
    var isSSLSecure: Bool {
        switch certificateSSL {
        case .ssl_certificate_pkcs12(let file, let passphrase):
            return true
        case .ssl_certificate_pkcs12_data(let bytes,let passphrase):
            return true
        case .none:
            return false
        }
    }
    
    /// isServer Active
    var isActive: Bool {
        return channel?.isActive ?? false
    }
    
    /// The server's host.
    private let host: String
    /// The server's port.
    private var _port: Int = 8080
    /// The server's max frame
    private var maxFrameSize: Int = 16384
    /// The server's SSL Certificate
    private var certificateSSL: NIOSSLCertificateType = .none
    
    /// The server's event loop group.
    private let group: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    /// Server's channel
    private var channel: Channel?
    /// Server's boostrap
    private var bootstrap: ServerBootstrap?
    
    /// Server's socket handler
    private let websocketHandler: WebSocketHandler = WebSocketHandler()
    
    /// Server's http handler
    private let httpHandler: HTTPHandler = HTTPHandler()
    
    /// Server's Connected Channel
    private(set) var connectedChannels: [String : ChannelHandlerContext] = [:]
    
    /// Server's Socket out notify
    private var _socketOutNotify:NIOSSLServerSocketNotifyCallBack?
    
    /// 初始化服务
    /// - Parameters:
    ///   - host: 名称
    ///   - maxFrameSize: 最大帧
    ///   - certificateSSL: SSL验证
    init(host: String,
         maxFrameSize: Int = 16384,
         certificateSSL: NIOSSLCertificateType = .none) {
        self.host = host
        self.maxFrameSize = maxFrameSize
        self.certificateSSL = certificateSSL
    }
    
    
    private func initServer() -> ServerBootstrap {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self else {
                    return channel.eventLoop.makeFailedFuture(ChannelError.alreadyClosed)
                }
                
                guard let sslContext = try? self.serverSSLContext() else {
                    return self.configureWebSocketChannel(channel: channel)
                }
                
                /// 配置ssl上下文
                return channel.pipeline.addHandler(NIOSSLServerHandler(context: sslContext)).flatMap {
                    return self.configureWebSocketChannel(channel: channel)
                }
                
            }
            // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        return bootstrap
    }
    
    
    /// 配置服务器SSL
    /// - Returns: 结果
    private func serverSSLContext() throws -> NIOSSLContext? {
        
        switch certificateSSL {
        case .ssl_certificate_pkcs12_data(let bytes,let passphrase):
            guard let p12Bundle = try? NIOSSLPKCS12Bundle(buffer: bytes, passphrase: passphrase.utf8) else { return nil }
            
            let config = TLSConfiguration.makeServerConfiguration(certificateChain: p12Bundle.certificateChain.map { .certificate($0) }, privateKey: .privateKey(p12Bundle.privateKey))
            
            return try NIOSSLContext(configuration: config)
        case .ssl_certificate_pkcs12(let file, let passphrase):
            guard let p12Bundle = try? NIOSSLPKCS12Bundle(file: file, passphrase: passphrase.utf8) else { return nil }
            
            let config = TLSConfiguration.makeServerConfiguration(certificateChain: p12Bundle.certificateChain.map { .certificate($0) }, privateKey: .privateKey(p12Bundle.privateKey))
            
            return try NIOSSLContext(configuration: config)
        case .none:
            return nil
        }
    }
    
    /// 配置Socket通道
    /// - Parameter channel: 通道
    /// - Returns: 结果
    private func configureWebSocketChannel(channel: Channel) -> EventLoopFuture<Void> {
        /// socket通道连接
        websocketHandler.channelAdded = { [weak self] context in
            guard let self else { return }
            
            self.cacheChannel(context)
            
            let key = self.channelKey(context) ?? ""
            
            self._socketOutNotify?(.connect(channelId: key))
        }
        /// socket通道关闭
        websocketHandler.channelClose = { [weak self] context in
            guard let self else { return }
            
            self.clearChannel(context)
            
            let key = self.channelKey(context) ?? ""
            
            self._socketOutNotify?(.disconnect(channelId: key))
        }
        
        /// socket服务错误导致的关闭
        websocketHandler.channelErrorClose = { [weak self] context, code in
            guard let self else { return }
            
            self.clearChannel(context)
            
            let key = self.channelKey(context) ?? ""
            
            self._socketOutNotify?(.close(channelId: key, code: code))
        }
        
        /// socket收到数据
        websocketHandler.channelReceive = { [weak self] receive in
            guard let self else { return }
    
            switch receive {
            case .socket_data(let context, let data):
                let key = self.channelKey(context) ?? ""
                self._socketOutNotify?(.data(channelId: key, data: data))
            case .socket_text(let context, let text):
                let key = self.channelKey(context) ?? ""
                self._socketOutNotify?(.text(channelId: key, text: text))
            }
        }
        
        
        let upgrader = NIOWebSocketServerUpgrader(maxFrameSize: maxFrameSize) { channel, head in
            channel.eventLoop.makeSucceededFuture(HTTPHeaders())
        } upgradePipelineHandler: { [weak self] channel, _ in
            guard let self else {
                return channel.eventLoop.makeFailedFuture(ChannelError.alreadyClosed)
            }
            
            /// 处理片段帧, 聚合成完整的帧
            return channel.pipeline.addHandler(NIOWebSocketFrameAggregator(minNonFinalFragmentSize: 1, maxAccumulatedFrameCount: 1<<16, maxAccumulatedFrameSize: maxFrameSize)).flatMap {
                return channel.pipeline.addHandler(self.websocketHandler)
            }
        }
        
        let config: NIOHTTPServerUpgradeConfiguration = (
                           upgraders: [ upgrader ],
                           completionHandler: { [weak self] _ in
                               guard let self else {
                                   return
                               }
                               return channel.pipeline.removeHandler(self.httpHandler, promise: nil)
                           }
                       )
        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap { [weak self] in
            guard let self else {
                return channel.eventLoop.makeFailedFuture(ChannelError.alreadyClosed)
            }
            return channel.pipeline.addHandler(self.httpHandler)
        }
    }
}

// MARK: 服务器公开的接口
extension NIOHttpServer {
    /// 定义回调
    public typealias NIOSSLServerSocketNotifyCallBack = (_ receive: NIOServerReceiveSocket) -> Void
    
    public enum NIOSSLCertificateType {
        /// p12证书文件
        case ssl_certificate_pkcs12(file: String, passphrase: String)
        /// p12证书内容
        case ssl_certificate_pkcs12_data(bytes: [UInt8], passphrase: String)
        
        case none
    }
    
    /// 服务发送数据类型
    public enum NIOServerSendData {
        /// websocket写text
        case socket_text(channelId: String, text: String)
        
        /// websocket写data
        case socket_data(channelId: String, data: Data)
        
        ///  http写入text
        case http(channelId: String, text: String)
    }
    
    /// 服务器接收类型
    public enum NIOServerReceiveSocket {
        ///  客户端连接上服务器
        case connect(channelId: String)
        ///  客户端断开连接
        case disconnect(channelId: String)
        /// 服务器关闭连接
        case close(channelId: String, code: WebSocketErrorCode)
        /// 收到文本
        case text(channelId: String, text: String)
        ///  收到data
        case data(channelId: String, data: Data)
    }
    
    /// 启动服务器
    /// - Parameter port: 端口
    /// - Returns: 结果
    public func start(port: Int) -> Error? {
        do {
            let bootstrap = initServer()
            self.bootstrap = bootstrap
            /// 绑定并启动服务
        
            let channel = try bootstrap.bind(host: host, port: port).wait()
            self.channel = channel
            self._port = port
            return nil
        } catch let error {
            return error
        }
    }
    
    
    /// 关闭服务
    public func stop() throws {
        clearChannelAll()
        
        channel?.close()
        try group.syncShutdownGracefully()

    }
    
    
    /// 发送数据
    /// - Parameter data: 数据
    public func sendServer(data: NIOServerSendData) {
        switch data {
        case .socket_text(let channelId,  let text):
            guard let context = connectedChannels[channelId] else { return  }
            
            websocketHandler.sendServer(context: context, text: text)
        case .socket_data(let channelId, let data):
            guard let context = connectedChannels[channelId] else { return  }
            
            websocketHandler.sendServer(context: context, data: data)
        case .http(let channelId, let text):
            break
        }

    }
    
    /// Server's Socket OutNotify
    public func socketNotify(_ notify:@escaping NIOSSLServerSocketNotifyCallBack) {
        self._socketOutNotify = notify
    }
    
    
    /// Server's Channel On
    public func isChannelOn(_ channelId: String) -> Bool {
        guard let channel = connectedChannels[channelId] else {
            return false
        }
        return channel.channel.isActive
    }
}


// MARK: HTTP相关的处理回调
extension NIOHttpServer {
  
    fileprivate final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
        let websocketResponse = """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>Swift NIO WebSocket Test Page</title>
            <script>
                var wsconnection = new WebSocket("ws://localhost:8888/websocket");
                wsconnection.onmessage = function (msg) {
                    var element = document.createElement("p");
                    element.innerHTML = msg.data;
        
                    var textDiv = document.getElementById("websocket-stream");
                    textDiv.insertBefore(element, null);
                };
            </script>
          </head>
          <body>
            <h1>WebSocket Stream</h1>
            <div id="websocket-stream"></div>
          </body>
        </html>
        """
        
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart
        
        private var responseBody: ByteBuffer!
        
        func handlerAdded(context: ChannelHandlerContext) {
            self.responseBody = context.channel.allocator.buffer(string: websocketResponse)
        }
        
        func handlerRemoved(context: ChannelHandlerContext) {
            self.responseBody = nil
        }
        
        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let reqPart = self.unwrapInboundIn(data)
            
            // We're not interested in request bodies here: we're just serving up GET responses
            // to get the client to initiate a websocket request.
            guard case .head(let head) = reqPart else {
                return
            }
            
            // GETs only.
            guard case .GET = head.method else {
                self.respond405(context: context)
                return
            }
            
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/html")
            headers.add(name: "Content-Length", value: String(self.responseBody.readableBytes))
            headers.add(name: "Connection", value: "close")
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                                status: .ok,
                                                headers: headers)
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(self.responseBody))), promise: nil)
            context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
                context.close(promise: nil)
            }
            context.flush()
        }
        
        private func respond405(context: ChannelHandlerContext) {
            var headers = HTTPHeaders()
            headers.add(name: "Connection", value: "close")
            headers.add(name: "Content-Length", value: "0")
            let head = HTTPResponseHead(version: .http1_1,
                                        status: .methodNotAllowed,
                                        headers: headers)
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
                context.close(promise: nil)
            }
            context.flush()
        }
    }
}

// MARK: WebSocket相关的处理回调
extension NIOHttpServer {
    
    /// 服务接收数据
    fileprivate enum WebSocketReceiveData {
        /// websocket写text
        case socket_text(context: ChannelHandlerContext, text: String)
        
        /// websocket写data
        case socket_data(context: ChannelHandlerContext, data: Data)
    }
    
    /// websocket处理回调
    fileprivate final class WebSocketHandler: ChannelInboundHandler {
        typealias InboundIn = WebSocketFrame
        typealias OutboundOut = WebSocketFrame
        
        /// socket connected
        var channelAdded:((_ context: ChannelHandlerContext) -> Void)?
        
        /// socket 接收到数据
        var channelReceive:((_ data: WebSocketReceiveData) -> Void)?
        
        /// socket关闭
        var channelClose:((_ context: ChannelHandlerContext) -> Void)?
        
        /// socket错误关闭
        var channelErrorClose:((_ context: ChannelHandlerContext,_ code: WebSocketErrorCode) -> Void)?
        

        private var awaitingClose: Bool = false

        public func handlerAdded(context: ChannelHandlerContext) {
            
            channelAdded?(context)
        }

        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let frame = self.unwrapInboundIn(data)

            switch frame.opcode {
            case .connectionClose:
                self.receivedClose(context: context, frame: frame)
                
                channelClose?(context)
            case .ping:
                self.pong(context: context, frame: frame)
            case .text:
                var data = frame.unmaskedData
                let text = data.readString(length: data.readableBytes) ?? ""
                
                channelReceive?(.socket_text(context: context, text: text))
            case .binary:
                var buffer = frame.unmaskedData
                let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
                let data = Data(bytes)
    
                channelReceive?(.socket_data(context: context, data: data))
            case .continuation, .pong:
                // We ignore these frames.
                break
            default:
                // Unknown frames are errors.
                self.closeOnError(context: context)
                
                channelErrorClose?(context, .protocolError)
            }
        }

        public func channelReadComplete(context: ChannelHandlerContext) {
            context.flush()
        }

        private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
            // Handle a received close frame. In websockets, we're just going to send the close
            // frame and then close, unless we already sent our own close frame.
            if awaitingClose {
                // Cool, we started the close and were waiting for the user. We're done.
                context.close(promise: nil)
            } else {
                // This is an unsolicited close. We're going to send a response frame and
                // then, when we've sent it, close up shop. We should send back the close code the remote
                // peer sent us, unless they didn't send one at all.
                var data = frame.unmaskedData
                let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
                let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
                _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
                    context.close(promise: nil)
                }
            }
        }

        private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
            var frameData = frame.data
            let maskingKey = frame.maskKey

            if let maskingKey = maskingKey {
                frameData.webSocketUnmask(maskingKey)
            }

            let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
            context.write(self.wrapOutboundOut(responseFrame), promise: nil)
        }

        private func closeOnError(context: ChannelHandlerContext) {
            // We have hit an error, we want to close. We do that by sending a close frame and then
            // shutting down the write side of the connection.
            var data = context.channel.allocator.buffer(capacity: 2)
            data.write(webSocketErrorCode: .protocolError)
            let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
            context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
                context.close(mode: .output, promise: nil)
            }
            awaitingClose = true
        }
    }
 

}

/// 通道操作
extension NIOHttpServer {
    
    /// 获取会话key
    /// - Parameter session: 会话
    /// - Returns: 结果
    private func channelKey(_ channel: ChannelHandlerContext) -> String? {
        guard let key = channel.remoteAddress?.description else {
            return nil
        }
        
        return key
    }
    
    /// 缓存WebSocket会话
    /// - Parameter session: 会话
    private func cacheChannel(_ channel: ChannelHandlerContext) {
        guard let key = channelKey(channel) else {
            return
        }
        
        connectedChannels[key] = channel
    }
    
    /// 清除WebSocket会话
    /// - Parameter session: 会话
    private func clearChannel(_ channel: ChannelHandlerContext) {
        guard let key = channelKey(channel) else {
            return
        }
        
        connectedChannels.removeValue(forKey: key)
    }
    
    /// 清理所有的会话
    private func clearChannelAll() {
        guard !connectedChannels.isEmpty else {
            return
        }
        
        connectedChannels.removeAll()
    }
}
extension NIOHttpServer.WebSocketHandler {
    
    /// 发送文本
    /// - Parameters:
    ///   - context: 通道上下文
    ///   - text: 文本
    fileprivate func sendServer(context: ChannelHandlerContext, text: String) {
        context.eventLoop.execute {
            guard context.channel.isActive else { return }

            // We can't send if we sent a close message.
            guard !self.awaitingClose else { return }

            // We can't really check for error here, but it's also not the purpose of the
            // example so let's not worry about it.

            var buffer = context.channel.allocator.buffer(capacity: text.count)
            buffer.writeString(text)

            let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
            context.writeAndFlush(self.wrapOutboundOut(frame)).whenFailure { (_: Error) in

            }
        }

    }
    
    /// 发送Data
    /// - Parameters:
    ///   - context: 通道上下文
    ///   - data: Data
    fileprivate func sendServer(context: ChannelHandlerContext, data: Data) {
        context.eventLoop.execute {
            guard context.channel.isActive else { return }

            // We can't send if we sent a close message.
            guard !self.awaitingClose else { return }

            // We can't really check for error here, but it's also not the purpose of the
            // example so let's not worry about it.

            let bytes: [UInt8] = data.withUnsafeBytes {
                Array($0.bindMemory(to: UInt8.self))
            }
            
            var buffer = context.channel.allocator.buffer(capacity: bytes.count)
            buffer.writeBytes(bytes)

            let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
            context.writeAndFlush(self.wrapOutboundOut(frame)).whenFailure { (_: Error) in
                
            }
        }
    }
    
    private func sendTime(context: ChannelHandlerContext) {
        guard context.channel.isActive else { return }

        // We can't send if we sent a close message.
        guard !self.awaitingClose else { return }

        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        let theTime = NIODeadline.now().uptimeNanoseconds
        var buffer = context.channel.allocator.buffer(capacity: 12)
        buffer.writeString("\(theTime)")

        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        context.writeAndFlush(self.wrapOutboundOut(frame)).map {
            context.eventLoop.scheduleTask(in: .seconds(1), { self.sendTime(context: context) })
        }.whenFailure { (_: Error) in
            context.close(promise: nil)
        }
    }
}
