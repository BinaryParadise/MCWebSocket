//
//  MCWSStream.h
//  MCWebSocket
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCLogger.h"

@protocol MCWSStreamDelegate;

@interface MCWSStream : NSObject

/**
 开启WebSocket服务

 @param delegate 代理
 @param wsport 端口
 */
- (void)startWithDelegate:(id<MCWSStreamDelegate>)delegate port:(UInt16)wsport;

/**
 发送消息

 @param message 消息内容
 @param tag 标识
 */
- (void)sendMessage:(NSString *)message withTag:(long)tag;

/**
 发送数据
 
 @param message 数据
 @param tag 标识
 */
- (void)sendData:(NSData *)data withTag:(long)tag;

@end

@protocol MCWSStreamDelegate <NSObject>

- (void)webSocket:(MCWSStream *)stream didHandshake:(BOOL)result;


/**
 收到消息

 @param stream 流对象
 @param message 消息内容
 @param tag 标识
 */
- (void)webSocket:(MCWSStream *)stream didReceiveMessage:(NSString *)message withTag:(long)tag;

@end
