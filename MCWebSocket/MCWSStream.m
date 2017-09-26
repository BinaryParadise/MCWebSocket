//
//  MCWSStream.m
//  MCWebSocket
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "MCWSStream.h"
#import "NSString+Crypto.h"
#include <Endian.h>

#define kMCSecWebSocketKey  @"Sec-WebSocket-Key"

typedef enum  {
    WSOpCodeTextFrame = 0x1,
    WSOpCodeBinaryFrame = 0x2,
    // 3-7 reserved.
    WSOpCodeConnectionClose = 0x8,
    WSOpCodePing = 0x9,
    WSOpCodePong = 0xA,
    // B-F reserved.
} WSOpCode;

typedef struct {
    BOOL fin;
    //  BOOL rsv1;
    //  BOOL rsv2;
    //  BOOL rsv3;
    uint8_t opcode;
    BOOL masked;
    uint64_t payload_length;
} frame_header;

/* From RFC6455:
 
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-------+-+-------------+-------------------------------+
 |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 | |1|2|3|       |K|             |                               |
 +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 |     Extended payload length continued, if payload len == 127  |
 + - - - - - - - - - - - - - - - +-------------------------------+
 |                               |Masking-key, if MASK set to 1  |
 +-------------------------------+-------------------------------+
 | Masking-key (continued)       |          Payload Data         |
 +-------------------------------- - - - - - - - - - - - - - - - +
 :                     Payload Data continued ...                :
 + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 |                     Payload Data continued ...                |
 +---------------------------------------------------------------+
 */

static const uint8_t WSFinMask          = 0x80;
static const uint8_t WSOpCodeMask       = 0x0F;
static const uint8_t WSRsvMask          = 0x70;
static const uint8_t WSMaskMask         = 0x80;
static const uint8_t WSPayloadLenMask   = 0x7F;

#define WS_TAG_HTTPREQ  100
#define WS_TAG_PREFIX   200
#define WS_TAG_PAYLOAD  300

@import CocoaAsyncSocket;

@interface MCWSStream () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, strong) NSMutableDictionary *mdict;

@end

@implementation MCWSStream

- (void)startWithPort:(UInt16)wsport {
    self.asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    NSError *error;
    [self.asyncSocket acceptOnPort:wsport error:&error];
    MCLogError(@"%@", error);
    self.mdict = [NSMutableDictionary dictionary];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    MCLogWarn(@"");
    @synchronized (self.mdict) {
        [self.mdict setObject:newSocket forKey:@(newSocket.hash)];
    }
    [newSocket readDataWithTimeout:-1 tag:WS_TAG_HTTPREQ];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    MCLogWarn(@"");
}

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url {
    MCLogWarn(@"");
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (tag == WS_TAG_HTTPREQ) {
        NSString *reqString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSArray<NSString *> *allHeaders = [reqString componentsSeparatedByString:@"\r\n"];
        NSString *secWSKey = [allHeaders filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Sec-WebSocket-Key:'"]].firstObject;
        if (secWSKey) {
            //踩坑①：没有把Sec-WebSocket-Key去掉导致握手失败
            //踩坑②：sha1、base64的算法错误导致握手失败
            //踩坑③：Safari的响应代码101需要说明,否则握手失败
            secWSKey = [secWSKey substringFromIndex:kMCSecWebSocketKey.length+2];
            NSString *secWSAccpet = [secWSKey stringByAppendingString:@"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"];
            NSString *handshakeString = [NSString stringWithFormat:@"HTTP/1.1 101 WebSocket Protocol Handshake\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %@\r\n\r\n", secWSAccpet.sha1AndBase64String];
            [sock writeData:[handshakeString dataUsingEncoding:NSASCIIStringEncoding] withTimeout:5.0 tag:tag];
        }
        [sock readDataWithTimeout:-1 tag:WS_TAG_PREFIX];
        return;
    }else if(tag == WS_TAG_PREFIX) {
        MCLogWarn(@"%zd", data.length);
        uint8_t *buffer = (uint8_t *)data.bytes;
        WSOpCode opcode = buffer[0] & WSOpCodeMask;
        if (opcode == WSOpCodeTextFrame) {
            if (!!(buffer[1] & WSMaskMask)) {
                int pos = 2;
                uint64_t payLoadLength = buffer[1] & WSPayloadLenMask;
                if (payLoadLength == 126) {//125 < length < 65536
                    payLoadLength = EndianU16_BtoN(*(uint16_t *)(buffer + pos));
                    pos += 2;
                }else if (payLoadLength == 127) {
                    //length > 65535
                    payLoadLength = EndianU64_BtoN(*(uint64_t *)(buffer + pos));
                    pos += 8;
                }
                if (payLoadLength > UINT16_MAX) {
                    //暂不支持大于65535的数据长度
                    NSString *msg = [NSString stringWithFormat:@"WebSocket Data length too large: %zd, max payload: %d", payLoadLength, UINT16_MAX];
                    NSMutableData *msgData = [NSMutableData data];
                    [msgData appendBytes:"\x3\xf0" length:2];
                    [msgData appendBytes:msg.UTF8String length:msg.length];
                    NSData *responseData = [self createFrameWithOpcode:WSOpCodeConnectionClose data:msgData];
                    [sock writeData:responseData withTimeout:5.0 tag:tag];
                }else {
                    uint32_t mask = *(uint32_t *)(buffer + pos);
                    pos += 4;
                    const uint64_t pageSize = UINT16_MAX;
                    NSMutableData *msgData = [NSMutableData data];
                    uint64_t pageCount = payLoadLength/pageSize + (payLoadLength%pageSize>0?1:0);
                    for(uint64_t i = 0; i < pageCount; i++) {
                        char b[pageSize] = {0};
                        for (uint64_t j = i*pageSize; j < (i+1)*pageSize && j < payLoadLength; j++) {
                            b[j - i*pageSize] = buffer[pos + j] ^ ((uint8_t*)(&mask))[j%4];
                            if (b[j - i *pageSize] != 'a') {
                                MCLogWarn(@"");
                            }
                        }
                        [msgData appendBytes:b length:i > 0 && i == pageCount-1?MAX(payLoadLength%pageSize, 0):pageSize];
                    }
                    NSData *responseData = [self createFrameWithOpcode:WSOpCodeTextFrame data:msgData];
                    [sock writeData:responseData withTimeout:5.0 tag:tag];
                }
            }else {
                [sock disconnectAfterReading];
                return;
            }
        }
    }
}

/**
 * Called when a socket has read in data, but has not yet completed the read.
 * This would occur if using readToData: or readToLength: methods.
 * It may be used to for things such as updating progress bars.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    MCLogWarn(@"partialLength： %zd", partialLength);
    [sock readDataToLength:partialLength withTimeout:-1 tag:tag];
}

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    MCLogWarn(@"");
    [sock readDataWithTimeout:-1 tag:tag];
}

/**
 * Called when a socket has written some data, but has not yet completed the entire write.
 * It may be used to for things such as updating progress bars.
 **/
- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    
    MCLogWarn(@"");
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    return 5.0;
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    return 15.0;
}

- (void)socketDidCloseReadStream:(GCDAsyncSocket *)sock {
    
    MCLogWarn(@"");
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    
    MCLogWarn(@"%@", err);
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    
    MCLogWarn(@"");
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    
    MCLogWarn(@"");
}

//#define WSUseMask

#pragma mark - Private

- (NSData *)createFrameWithOpcode:(WSOpCode)opcode data:(NSData *)data {
    NSMutableData *frameData = nil;
    NSUInteger length = data.length;
    
    if (length <= 125) {
        frameData = [NSMutableData dataWithCapacity:length + 2];
        [frameData appendBytes:"\x81" length:1];
        UInt8 len = (UInt8)length;
        [frameData appendBytes:&len length:1];
        [frameData appendData:data];
    } else if (length <= 0xFFFF) {
        frameData = [NSMutableData dataWithCapacity:length + 4];
        [frameData appendBytes:"\x81\x7E" length:2];
        UInt16 len = (UInt16)length;
        [frameData appendBytes:(UInt8[]){len >> 8, len & 0xFF} length:2];
        [frameData appendData:data];
    } else {
        frameData = [NSMutableData dataWithCapacity:(length + 10)];
        [frameData appendBytes: "\x81\x7F" length:2];
        [frameData appendBytes: (UInt8[]){0, 0, 0, 0, (UInt8)(length >> 24), (UInt8)(length >> 16), (UInt8)(length >> 8), length & 0xFF} length:8];
        [frameData appendData:data];
    }
    uint8_t *buffer = (uint8_t *)frameData.mutableBytes;
    buffer[0] = WSMaskMask | opcode;
    return frameData;
}

- (void)didReceiveMessage:(NSString *)msg {

}

@end
