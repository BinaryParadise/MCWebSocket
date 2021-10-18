//
//  WebSocketServer.swift
//  
//
//  Created by Rake Yang on 2021/8/26.
//

import Foundation
import PracticeTLS
import Socket
import Crypto
import CoreFoundation

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
    @discardableResult func readData(_ tag: RWTags) -> [UInt8]
    
    func writeData(_ data: [UInt8]?, tag: RWTags)
    
    func disconnect()
}

public protocol WebSocketDelegate {
    func didReceive(data: [UInt8])
}

public class WebSocketServer: NSObject {
    var acceptSocket: Socket?
    var sessions: [Int : WebSocketStream] = [:]
    var terminated: Bool = false
    let socketQueue = DispatchQueue(label: "WebSocketQueue")
    var delegate: WebSocketDelegate?
    
    public init(tls: Bool = false, delegate: WebSocketDelegate? = nil) {
        super.init()
        self.delegate = delegate
        if tls {
            let bundle = Bundle(path: "\(Bundle(for: Self.self).resourcePath!)/MCWebSocket_MCWebSocket.bundle")!
            let identity = PEMFileIdentity(certificateFile: bundle.path(forResource: "Cert/localhost.crt", ofType: nil)!, privateKeyFile: bundle.path(forResource: "Cert/private.pem", ofType: nil)!)!
            TLSSessionManager.shared.identity = identity
            TLSSessionManager.shared.delegate = self
            TLSSessionManager.shared.isDebug = true
        }
        
        acceptSocket = try? Socket.create(family: .inet, type: .stream, proto: .tcp)
    }
    
    @discardableResult public func start(on port: UInt16) -> Self {
        do {
            try acceptSocket?.listen(on: Int(port))
            socketQueue.async { [weak self] in
                guard let self = self else { return }
                repeat {
                    if let newSocket = try? self.acceptSocket?.acceptClientConnection() {
                        self.socket(didAcceptNewSocket: newSocket)
                    }
                } while !self.terminated
            }
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
    
    func opcode(_ op: OpCode, data: Data, sock: WebSocketStream) {
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
    
    func asyncRead(_ socket: WebSocketStream, tag: RWTags) {
        if socket is TLSConnection {
            socket.readData(tag)
        } else {
            socketQueue.async { [weak self] in
                self?.didReadData(data: socket.readData(tag), stream: socket, rtag: tag)
            }
        }
    }
    
    func asyncWrite(_ socket: WebSocketStream, data: [UInt8], tag: RWTags) {
        if socket is TLSConnection {
            socket.writeData(data, tag: tag)
        } else {
            socketQueue.async { [weak self] in
                socket.writeData(data, tag: tag)
                self?.didWrite(socket, rtag: tag)
            }
        }
    }
    
    func didReadData(data: [UInt8], stream: WebSocketStream, rtag: RWTags) {
        LogDebug("\(rtag) -> \(data.count)")
        //TODO:需要处理粘包
        switch rtag {
        case .handshake:
            if let res = handshake(Data(data)) {
                asyncWrite(stream, data: res.bytes, tag: .handshake)
            } else {
                asyncWrite(stream, data: WebSocketFrame(opcode: .close, data: []).rawBytes(), tag: .frame(.binaryFrame))
            }
        case .frame(_):
            if let frame = WebSocketFrame(data) {
                switch frame.opcode {
                case .textFrame:
                    LogInfo(String(data: Data(frame.payloadData) , encoding: .utf8) ?? "")
                case .binaryFrame:
                    delegate?.didReceive(data: data)
                    asyncRead(stream, tag: .frame(.binaryFrame))
                case .close:
                    stream.disconnect()
                case .ping:
                    let ret = WebSocketFrame(opcode: .pong, data: frame.payloadData)
                    asyncWrite(stream, data: ret.rawBytes(), tag: .frame(.binaryFrame))
                case .pong:
                    break
                }
            } else {
                asyncRead(stream, tag: .frame(.binaryFrame))
            }
        }
    }
    
    func didWrite(_ stream: WebSocketStream, rtag: RWTags) {
        LogDebug("\(rtag)")
        switch rtag {
        case .handshake:
            asyncRead(stream, tag: .frame(.binaryFrame))
        case .frame(_):
            asyncRead(stream, tag: .frame(.binaryFrame))
        }
    }
}

extension WebSocketServer {
    
    public func socket(didAcceptNewSocket newSocket: Socket) {
        LogDebug("")
        if TLSSessionManager.shared.identity == nil {
            sessions[Int(newSocket.socketfd)] = newSocket
            newSocket.readData(.handshake)
        } else {
            TLSSessionManager.shared.acceptConnection(newSocket)
        }
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
        let sha1 = Insecure.SHA1.hash(data: bytes)
        let b = sha1.withUnsafeBytes { r in
            [UInt8](r.bindMemory(to: UInt8.self))
        }
        return b.data.base64EncodedString()
    }
}

extension Socket: WebSocketStream {
    
    @discardableResult func readData(_ tag: RWTags) -> [UInt8] {
        do {
            var data = Data()
            try read(into: &data)
            return data.bytes
        } catch {
            LogError("\(error)")
        }
        return []
    }
    
    func writeData(_ data: [UInt8]?, tag: RWTags) {
        guard let data = data else { return }
        do {
            try write(from: Data(data))
        } catch {
            LogError("\(error)")
        }
    }
    
    func disconnect() {
        close()
    }
}

extension TLSConnection: WebSocketStream {
    @discardableResult func readData(_ tag: RWTags) -> [UInt8] {
        readApplication(tag: tag.rawValue)
        return []
    }
    
    func writeData(_ data: [UInt8]?, tag: RWTags) {
        writeApplication(data: data ?? [], tag: tag.rawValue)
    }
}
