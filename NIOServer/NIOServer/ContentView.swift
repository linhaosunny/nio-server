//
//  ContentView.swift
//  NIOServer
//
//  Created by danxiao on 2024/7/3.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("SwiftNIO Server")
            .padding()
            .font(.title)
            .foregroundColor(.black)
            .cornerRadius(10)
        
        VStack(spacing: 30) {
            
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
