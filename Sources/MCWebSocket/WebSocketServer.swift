//
//  WebSocketServer.swift
//  
//
//  Created by Rake Yang on 2021/8/26.
//

import Foundation
import PracticeTLS
import CocoaAsyncSocket
import CommonCrypto

enum RWTags {
    typealias RawValue = UInt8
    case handshake
    case frame(OpCode)
    
    init(rawValue: UInt8) {
        if rawValue == 0 {
            self = .handshake
        } else {
            self = .frame(OpCode(rawValue: rawValue)!)
        }
    }
    
    var rawValue: Int {
        switch self {
        case .handshake:
        return 0
        case .frame(let op):
        return Int(op.rawValue)
        }
    }
}

protocol WebSocketStream {
    func readData(_ tag: RWTags)
    
    func writeData(_ data: [UInt8]?, tag: RWTags)
    
    func disconnect()
}

public class WebSocketServer: NSObject {
    var acceptSocket: GCDAsyncSocket?
    var sessions: [Int : GCDAsyncSocket] = [:]
    
    public init(tls: Bool = false) {
        super.init()
        if tls {
            let bundle = Bundle(path: "\(Bundle(for: Self.self).resourcePath!)/MCWebSocket_MCWebSocket.bundle")!
            let identity = PEMFileIdentity(certificateFile: bundle.path(forResource: "Cert/localhost.crt", ofType: nil)!, privateKeyFile: bundle.path(forResource: "Cert/private.pem", ofType: nil)!)!
            TLSSessionManager.shared.identity = identity
            TLSSessionManager.shared.delegate = self
            TLSSessionManager.shared.isDebug = true
        }
        
        acceptSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
        acceptSocket?.isIPv6Enabled = false
    }
    
    @discardableResult public func start(on port: UInt16) -> Self {
        do {
            try acceptSocket?.accept(onPort: port)
        } catch {
            LogError(error.localizedDescription)
        }
        LogInfo("start on:\(port)")
        return self
    }
    
    @discardableResult public func wait() -> Bool {
        CFRunLoopRun()
        return false
    }
    
    func handshake(_ data: Data) -> String? {
        let request = String(data: data, encoding: .ascii)
        if let allHeaders = request?.components(separatedBy: "\r\n\r\n").first?.appending("").split(separator: "\r\n") {
            if let secKey = allHeaders.first { sub in
                sub.starts(with: "Sec-WebSocket-Key")
            }?.split(separator: " ").last?.appending("") {
                let accpetKey = "\(secKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11".sha1AndBase64()
                let response = """
                    HTTP/1.1 101 WebSocket Protocol Handshake
                    Upgrade: websocket
                    Connection: Upgrade
                    Sec-WebSocket-Accept: \(accpetKey)
                    """
                    .replacingOccurrences(of: "\n", with: "\r\n")
                    .appending("\r\n\r\n")
                return response
            }
        }
        return nil
    }
    
    func opcode(_ op: OpCode, data: Data, sock: GCDAsyncSocket) {
        switch op {
        case .textFrame:
            break
        case .binaryFrame:
            break
        case .close:
            sock.disconnect()
        case .ping:
            break
        case .pong:
            break
        }
    }
    
    func didReadData(data: [UInt8], stream: WebSocketStream, rtag: RWTags) {
        LogDebug("-> \(data.count)")
        //TODO:需要处理粘包
        switch rtag {
        case .handshake:
            if let res = handshake(Data(data)) {
                stream.writeData(res.bytes, tag: .handshake)
            } else {
                stream.writeData(WebSocketFrame(opcode: .close, data: []).rawBytes(), tag: .frame(.binaryFrame))
            }
        case .frame(_):
            if let frame = WebSocketFrame(data) {
                switch frame.opcode {
                case .textFrame:
                    LogInfo(String(data: Data(frame.payloadData) , encoding: .utf8) ?? "")
                case .binaryFrame:
                    LogInfo("binary[\(frame.length)]")
                case .close:
                    stream.disconnect()
                case .ping:
                    let ret = WebSocketFrame(opcode: .pong, data: frame.payloadData)
                    stream.writeData(ret.rawBytes(), tag: .frame(.binaryFrame))
                case .pong:
                    break
                }
            } else {
                stream.readData(.frame(.binaryFrame))
            }
        }
    }
    
    func didWrite(_ stream: WebSocketStream, rtag: RWTags) {
        switch rtag {
        case .handshake:
            stream.readData(.frame(.binaryFrame))
        case .frame(_):
            stream.readData(.frame(.binaryFrame))
        }
    }
}

extension WebSocketServer: GCDAsyncSocketDelegate {
    
    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        LogDebug("")
        if TLSSessionManager.shared.identity == nil {
            sessions[Int(newSocket.socket4FD())] = newSocket
            newSocket.readData(.handshake)
        } else {
            TLSSessionManager.shared.acceptConnection(newSocket)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        didReadData(data: data.bytes, stream: sock, rtag: RWTags(rawValue: UInt8(tag)))
    }
    
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        didWrite(sock, rtag: RWTags(rawValue: UInt8(tag)))
    }
    
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        sessions.removeValue(forKey: Int(sock.socket4FD()))
        LogError("\(String(describing: err))")
    }
}

extension WebSocketServer: TLSConnectionDelegate {

    public func didHandshakeFinished(_ connection: TLSConnection) {
        connection.readData(.handshake)
    }
    
    public func didReadApplication(_ data: [UInt8], connection: TLSConnection, tag: Int) {
        didReadData(data: data, stream: connection, rtag: RWTags(rawValue: UInt8(tag)))
    }
    
    public func didWriteApplication(_ connection: TLSConnection, tag: Int) {
        didWrite(connection, rtag: RWTags(rawValue: UInt8(tag)))
    }
}

extension String {
    func sha1AndBase64() -> Self {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { p in
            _ = CC_SHA1(p.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.toBase64()
    }
}

extension GCDAsyncSocket: WebSocketStream {
    func readData(_ tag: RWTags) {
        readData(withTimeout: -1, tag: tag.rawValue)
    }
    
    func writeData(_ data: [UInt8]?, tag: RWTags) {
        write(Data(data ?? []), withTimeout: -1, tag: tag.rawValue)
    }
}

extension TLSConnection: WebSocketStream {
    func readData(_ tag: RWTags) {
        readApplication(tag: tag.rawValue)
    }
    
    func writeData(_ data: [UInt8]?, tag: RWTags) {
        writeApplication(data: data ?? [], tag: tag.rawValue)
    }
}
