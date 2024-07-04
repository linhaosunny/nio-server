A Clear Demo For SwiftNIO Server, Support TSL/SSL, UI Write by SwiftUI.

// demo functions

     func openServer() {
         LocalHttpServer.openWebSocketServer(isSSLSecure: serverStatus.isSSLCheck) { isSuccess in
            DispatchQueue.main.async {
                serverStatus.isStart = isSuccess
            }
        }
        
        serverStatus.listenBag = .init()
        LocalHttpServer.connectStatusSubject
            .subscribe(onNext: { status in
                DispatchQueue.main.async {
                    guard let status else { return }
                    if status.isConnect {
                        serverStatus.connections.append(status)
                    } else {
                        serverStatus.connections.removeAll(where: { $0.sessionId == status.sessionId})
                    }
                    
                }
            })
            .disposed(by: serverStatus.listenBag)
         
         LocalHttpServer.receiveSubject
             .subscribe(onNext: { context in
                 guard let context else {
                     return
                 }
        
                 /// response for the receive data
                 LocalHttpServer.serverSend(context.sessionId, text: context.content)
             })
             .disposed(by: serverStatus.listenBag)
    }
    
    func closeServr() {
        LocalHttpServer.closeWebSocketServer { isSuccess in
            DispatchQueue.main.async {
                serverStatus.isStart = !isSuccess
                guard isSuccess else { return }
                serverStatus.connections.removeAll()
            }
        }
    }
