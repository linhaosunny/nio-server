//
//  ContentView.swift
//  NIOServer
//
//  Created by danxiao on 2024/7/3.
//  A Demo For SwiftNIO Server

import SwiftUI
import Combine
import RxSwift

class ServerStatus: ObservableObject {
    @Published var isStart: Bool = false
    
    var listenBag: DisposeBag = .init()
    
    @Published var connections: [LocalHttpServer.SocketServerStatusDM] = []
}

extension LocalHttpServer.SocketServerStatusDM: Identifiable {
    var id: String { return self.sessionId }
}

struct ContentView: View {
    @ObservedObject var serverStatus = ServerStatus()
    

    
    var body: some View {
        Text("SwiftNIO Server")
            .padding()
            .font(.title)
            .foregroundColor(.black)
            .cornerRadius(10)
        
        
        VStack(spacing: 30) {
            Circle()
                .fill(serverStatus.isStart ? Color.green : Color.red)
                .overlay(Circle().stroke(.gray, lineWidth: 1.6))
                .frame(width: 24, height: 24)
            
            Button(action: {
                // Handle button 1 tap
                openServer()
            }) {
                Text("Open server")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button(action: {
                // Handle button 2 tap
                closeServr()
            }) {
                Text("Close server")
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            List(serverStatus.connections) { connection in
                // Display connection info
                Text(connection.sessionId)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

extension ContentView {
     func openServer() {
        LocalHttpServer.openWebSocketServer { isSuccess in
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
