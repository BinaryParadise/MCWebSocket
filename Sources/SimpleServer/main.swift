//
//  File.swift
//  
//
//  Created by Rake Yang on 2021/8/30.
//

import MCWebSocket

let server = WebSocketServer(tls: true)
server.start(on: 8443).wait()
