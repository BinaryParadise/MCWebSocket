//
//  File.swift
//  
//
//  Created by Rake Yang on 2021/8/30.
//

import MCWebSocket

class SimpleDelegate: WebSocketDelegate {
    func didReceive(data: [UInt8]) {
        print("\(#function) -> \(data.count)")
    }
}

let server = WebSocketServer(tls: true, delegate: SimpleDelegate())
server.start(on: 8443).wait()
