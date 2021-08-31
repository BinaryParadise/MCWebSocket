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

public class WebSocketServer: NSObject {
    var acceptSocket: GCDAsyncSocket?
    
    public init(tls: Bool = false) {
        super.init()
        if tls {
            let bundle = Bundle(path: "\(Bundle(for: Self.self).resourcePath!)/MCWebSocket_MCWebSocket.bundle")!
            let identity = PEMFileIdentity(certificateFile: bundle.path(forResource: "Cert/localhost.crt", ofType: nil)!, privateKeyFile: bundle.path(forResource: "Cert/private.pem", ofType: nil)!)!
            TLSSessionManager.shared.identity = identity
            TLSSessionManager.shared.delegate = self
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
}

extension WebSocketServer: GCDAsyncSocketDelegate {
    
    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        LogInfo("")
        if TLSSessionManager.shared.identity == nil {
            newSocket.read(tag: .handshake)
        } else {
            TLSSessionManager.shared.acceptConnection(newSocket)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        switch RWTags(rawValue: UInt8(tag)) {
        case .handshake:
            if let res = handshake(data) {
                sock.write(data: res.data(using: .utf8)?.bytes, tag: .handshake)
            }
        case .frame(_):
            let frame = WebSocketFrame(data)
            switch frame.opcode {
            case .textFrame:
                LogInfo(String(data: Data(frame.payloadData) , encoding: .utf8) ?? "")
                sock.read(tag: .frame(.textFrame))
            case .binaryFrame:
                LogInfo("binary[\(frame.length)]")
            case .close:
                sock.disconnectAfterReadingAndWriting()
            case .ping:
                break
            case .pong:
                let ret = WebSocketFrame(opcode: .pong, data: [0x01])
                sock.write(data: ret.rawBytes(), tag: .frame(.pong))
            }
        break
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        let wtag = RWTags(rawValue: UInt8(tag))
        switch wtag {
            
        case .handshake:
            let f = WebSocketFrame(opcode: .textFrame, data: "Hello,World!".bytes)
            sock.write(data: f.rawBytes(), tag: .frame(f.opcode))
        case .frame(let type):
            if type == .pong {
                sock.read(tag: .frame(.textFrame))
            }
            break
        default:
            break
        }
    }
    
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        LogError("\(err)")
    }
    
    
    
    public func didWrite(_ connection: TLSConnection, tag: Int) {
        let wtag = RWTags(rawValue: UInt8(tag-100))
        switch wtag {
        case .handshake:
            connection.writeApplication(data: "Hello,World!".bytes, tag: RWTags.frame(.textFrame).rawValue+100)
        case .frame(_):
            break
        }
    }
}

extension WebSocketServer: TLSConnectionDelegate {

    public func didHandshakeFinished(_ connection: TLSConnection) {
        connection.readApplication(tag: RWTags.handshake.rawValue)
    }
    
    public func didReadApplicaton(_ data: [UInt8], connection: TLSConnection, tag: Int) {
        let rtag = RWTags(rawValue: UInt8(tag))
        switch rtag {
        case .handshake:
            if let res = handshake(Data(data)) {
                connection.writeApplication(data: res.bytes, tag: RWTags.handshake.rawValue)
            } else {
                //TODO: 不支持请求方式
            }
        case .frame(_):
            let frame = WebSocketFrame(Data(data))
            switch frame.opcode {
            case .textFrame:
                LogInfo(String(data: Data(frame.payloadData) , encoding: .utf8) ?? "")
            case .binaryFrame:
                LogInfo("binary[\(frame.length)]")
            case .close:
                connection.sock.disconnectAfterReadingAndWriting()
            break
            case .ping:
                let ret = WebSocketFrame(opcode: .pong, data: [0x01])
                connection.writeApplication(data: ret.rawBytes(), tag: RWTags.frame(.textFrame).rawValue)
            case .pong:
                break
            }
        }
    }
    
    public func didWriteApplication(_ connection: TLSConnection, tag: Int) {
        let wtag = RWTags(rawValue: UInt8(tag))
        switch wtag {
        case .handshake:
            let f = WebSocketFrame(opcode: .textFrame, data: "Hello,World!".bytes)
            connection.writeApplication(data: f.rawBytes(), tag: RWTags.frame(.textFrame).rawValue)
        case .frame(_):
            connection.readApplication(tag: RWTags.frame(.textFrame).rawValue)
            break
        }
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

extension GCDAsyncSocket {
    func read(tag: RWTags) {
        readData(withTimeout: -1, tag: tag.rawValue)
    }
    
    func write(data: [UInt8]?, tag: RWTags) {
        write(Data(data ?? []), withTimeout: -1, tag: tag.rawValue)
    }
}
