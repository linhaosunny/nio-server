//
//  ContentView.swift
//  NIOServer
//
//  Created by danxiao on 2024/7/3.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                // Handle button 1 tap
                openServer()
            }) {
                Text("打开服务器")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Button(action: {
                // Handle button 2 tap
                closeServr()
            }) {
                Text("关闭服务器")
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

extension ContentView {
    func openServer() {
        LocalHttpServer.openWebSocketServer()
    }
    
    func closeServr() {
        LocalHttpServer.closeWebSocketServer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
