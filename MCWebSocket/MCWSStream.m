//
//  MCWSStream.m
//  MCWebSocket
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "MCWSStream.h"
#import "NSString+Crypto.h"
#if TARGET_OS_IPHONE
#include <Endian.h>
#else
#include <machine/endian.h>
#endif

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

static const uint8_t WSOpCodeMask       = 0x0F;
static const uint8_t WSRsvMask          = 0x70;
static const uint8_t WSMaskMask         = 0x80;
static const uint8_t WSPayloadLenMask   = 0x7F;

#define TAG_HANDSHAKE           201
#define TAG_PREFIX              202
#define TAG_PAYLOAD_LENGTH      203
#define TAG_PAYLOAD_LENGTH16    204
#define TAG_PAYLOAD_LENGTH64    205
#define TAG_MASKEDKEY           206
#define TAG_PAYLOAD             207

@import CocoaAsyncSocket;

@interface MCWSFrame : NSObject

@property (nonatomic, assign) uint8_t opcode;
@property (nonatomic, assign) uint64_t payloadLength;
@property (nonatomic, assign) BOOL masked;
@property (nonatomic, copy) NSData *maskKey;

@end

@implementation MCWSFrame

@end

@interface MCWSStream () <GCDAsyncSocketDelegate> {
    __weak id<MCWSStreamDelegate> delegate;
}

@property (nonatomic, strong) GCDAsyncSocket *asyncSocket;
@property (nonatomic, strong) NSMutableDictionary *mdict;

@end

@implementation MCWSStream

- (void)startWithDelegate:(id<MCWSStreamDelegate>)aDelegate port:(UInt16)wsport {
    delegate = aDelegate;
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
    [newSocket readDataWithTimeout:-1 tag:TAG_HANDSHAKE];
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    MCLogWarn(@"%ld", tag);
    if (tag == TAG_HANDSHAKE) {
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
        if ([delegate respondsToSelector:@selector(webSocket:didHandshake:)]) {
            [delegate webSocket:self didHandshake:secWSKey];
        }
        [sock readDataToLength:1 withTimeout:-1 tag:TAG_PREFIX];
    }else if(tag == TAG_PREFIX) {
        UInt8 *pFrame = (UInt8 *)[data bytes];
        UInt8 frame = *pFrame;
        if ([self isValidWebSocketFrame:frame]) {
            [sock readDataToLength:1 withTimeout:-1 tag:TAG_PAYLOAD_LENGTH];
        }else {
            NSString *msg = [NSString stringWithFormat:@"Unknown frame opcode."];
            NSMutableData *msgData = [NSMutableData data];
            [msgData appendBytes:"\x3\xea" length:2];
            [msgData appendBytes:msg.UTF8String length:msg.length];
            NSData *responseData = [self createFrameWithOpcode:WSOpCodeConnectionClose data:msgData];
            [sock writeData:responseData withTimeout:-1 tag:tag];
        }
    }else if (tag == TAG_PAYLOAD_LENGTH) {
        uint8_t *pFrame = (uint8_t *)[data bytes];
        if (pFrame[0] & WSMaskMask) {
            MCWSFrame *wsFrame = [MCWSFrame new];
            wsFrame.masked = YES;
            uint8_t length = pFrame[0] & WSPayloadLenMask;
            wsFrame.payloadLength = length;
            sock.userData = wsFrame;
            if (length < 126) {
                [sock readDataToLength:4 withTimeout:-1 tag:TAG_MASKEDKEY];
            }else if(length == 126) {
                [sock readDataToLength:2 withTimeout:-1 tag:TAG_PAYLOAD_LENGTH16];
            }else {
                [sock readDataToLength:8 withTimeout:-1 tag:TAG_PAYLOAD_LENGTH64];
            }
        }
    }else if (tag == TAG_PAYLOAD_LENGTH16) {
        uint8_t *pFrame = (uint8_t *)data.bytes;
        MCWSFrame *wsFrame = sock.userData;
        wsFrame.payloadLength = EndianU16_BtoN(*(uint16_t *)(pFrame));
        [sock readDataToLength:4 withTimeout:-1 tag:TAG_MASKEDKEY];
    }else if (tag == TAG_PAYLOAD_LENGTH64) {
        uint8_t *pFrame = (uint8_t *)data.bytes;
        MCWSFrame *wsFrame = sock.userData;
        wsFrame.payloadLength  = EndianU64_BtoN(*(uint64_t *)(pFrame));
        if (wsFrame.payloadLength <= UINT16_MAX) {
            [sock readDataToLength:4 withTimeout:-1 tag:TAG_MASKEDKEY];
        }else {
            //暂不支持大于65535的数据长度
            NSString *msg = [NSString stringWithFormat:@"WebSocket Data length too large: %zd, max payload: %d", wsFrame.payloadLength, UINT16_MAX];
            NSMutableData *msgData = [NSMutableData data];
            [msgData appendBytes:"\x3\xf0" length:2];
            [msgData appendBytes:msg.UTF8String length:msg.length];
            NSData *responseData = [self createFrameWithOpcode:WSOpCodeConnectionClose data:msgData];
            [sock writeData:responseData withTimeout:5.0 tag:tag];
        }
    }else if (tag == TAG_MASKEDKEY) {
        MCWSFrame *wsFrame = sock.userData;
        wsFrame.maskKey = data.copy;
        [sock readDataToLength:wsFrame.payloadLength withTimeout:-1 tag:TAG_PAYLOAD];
    }else if (tag == TAG_PAYLOAD) {
        MCWSFrame *wsFrame = sock.userData;
        uint8_t *mask = (uint8_t *)wsFrame.maskKey.bytes;
        NSMutableData *msgData = [NSMutableData data];
        NSUInteger payLoadLength = data.length;
        uint8_t *payLoad = (uint8_t *)data.bytes;
        for (uint64_t i=0; i < payLoadLength; i++) {
            payLoad[i] = payLoad[i] ^ mask[i % 4];
        }
        [msgData appendBytes:payLoad length:payLoadLength];
        NSData *responseData = [self createFrameWithOpcode:WSOpCodeTextFrame data:msgData];
        [sock writeData:responseData withTimeout:-1 tag:0];
        if ([delegate respondsToSelector:@selector(webSocket:didReceiveMessage:)]) {
            [delegate webSocket:self didReceiveMessage:[[NSString alloc] initWithBytes:payLoad length:payLoadLength encoding:NSUTF8StringEncoding]];
        }
        [sock readDataToLength:1 withTimeout:-1 tag:TAG_PREFIX];
    }
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

- (BOOL)isValidWebSocketFrame:(UInt8)frame
{
    NSUInteger rsv =  frame & WSRsvMask;
    NSUInteger opcode = frame & WSOpCodeMask;
    if (rsv || (3 <= opcode && opcode <= 7) || (0xB <= opcode && opcode <= 0xF))
    {
        return NO;
    }
    return YES;
}

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
