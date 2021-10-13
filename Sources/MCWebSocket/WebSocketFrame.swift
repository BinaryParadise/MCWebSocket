//
//  WebSocketFrame.swift
//  
//
//  Created by Rake Yang on 2021/8/30.
//

import Foundation
import PracticeTLS

let OpCodeMask      : UInt8 = 0x0F
let RsvMask         : UInt8 = 0x70
let MaskMask        : UInt8 = 0x80
let PayloadLenMask  : UInt8 = 0x7F

enum OpCode: UInt8 {
    case textFrame = 0x1
    case binaryFrame = 0x2
    // 3-7 reserved.
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
    // B-F reserved.
}

class WebSocketFrame {
    
    /// 是否最后一个分片
    var fin: Bool = true
    var rsv1: Bool = false
    var rsv2: Bool = false
    var rsv3: Bool = false
    var opcode: OpCode = .textFrame
    var mask: Bool = false
    var valid: Bool = true
    var length: UInt64
    var maskingKey: [UInt8] = []
    var payloadData: [UInt8] = []
    /// 粘包处理
    static var buffer: [UInt8] = []
    
    init?(_ data: [UInt8]) {
        WebSocketFrame.buffer.append(contentsOf: data)
        let stream = WebSocketFrame.buffer.stream
        let head = stream.readByte()!
        fin = head & 0b10000000 != 0
        rsv1 = head & 0b01000000 != 0
        rsv2 = head & 0b00100000 != 0
        rsv3 = head & 0b00010000 != 0
        if let oc = OpCode(rawValue: head & OpCodeMask) {
            opcode = oc
        } else {
            return nil
        }
                
        valid = Self.isValid(head)
        
        guard let second = stream.readByte() else { return nil}
        
        mask = second & MaskMask != 0
        
        let payloadLen = second & PayloadLenMask
                
        if payloadLen < 126 {
            length = UInt64(payloadLen)
        } else if payloadLen == 126 {
            length = UInt64(stream.readUInt16()!)
        } else {
            length = UInt64(stream.read(count: 8)!.int64Value)
        }
        if mask {
            if let maskKey = stream.read(count: 4) {
                maskingKey = maskKey
            } else {
                return nil
            }
        }
                
        if UInt64(stream.position) + length > stream.data.count {
            return nil
        }
                
        if let payload = stream.read(count: Int(length)) {
            payloadData = payload
            //反掩码
            for i in 0..<length {
                payloadData[Int(i)] = payloadData[Int(i)] ^ maskingKey[Int(i % 4)]
            }
        }
        WebSocketFrame.buffer.removeAll()
    }
    
    init(opcode: OpCode, data: [UInt8]) {
        fin = true
        self.opcode = opcode
        length = UInt64(data.count)
        payloadData = data
    }
    
    func rawBytes() -> [UInt8] {
        var bytes: [UInt8] = []
        var head: UInt8 = 0b00000000
        if fin {
            head |= 0b10000000
        }
        head |= opcode.rawValue & OpCodeMask
        bytes.append(head)
        if (length < 126) {
            bytes.append(UInt8(truncatingIfNeeded: length))
        } else if (length == 126) {
            bytes.append(0x7E)
            bytes.append(contentsOf: UInt16(length).bytes)
        } else {
            bytes.append(0x7F)
            bytes.append(contentsOf: length.bytes)
        }
        
        bytes.append(contentsOf: payloadData)
        return bytes
    }
    
    class func isValid(_ head: UInt8) -> Bool {
        let rsv =  head & RsvMask
        let opcode = head & OpCodeMask
        if (rsv != 0 || (3 <= opcode && opcode <= 7) || (0xB <= opcode && opcode <= 0xF))
        {
            return false
        }
        return true
    }
}
