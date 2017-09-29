//
//  MCWSStream.h
//  MCWebSocket
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import <Foundation/Foundation.h>

#if DEBUG
#define XCODE_COLORS_ESCAPE @"\033["

#define XCODE_COLORS_RESET_FG  XCODE_COLORS_ESCAPE @"fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  XCODE_COLORS_ESCAPE @"bg;" // Clear any background color
#define XCODE_COLORS_RESET     XCODE_COLORS_ESCAPE @";"   // Clear any foreground or background color

#define MCLogInfo(frmt, ...) NSLog((XCODE_COLORS_ESCAPE @"fg85,85,75;%s+%d " frmt XCODE_COLORS_RESET),__func__,__LINE__, ##__VA_ARGS__)
#define MCLogWarn(frmt, ...) NSLog((XCODE_COLORS_ESCAPE @"fg153,102,51;%s+%d " frmt XCODE_COLORS_RESET),__func__,__LINE__, ##__VA_ARGS__)
#define MCLogError(frmt, ...) NSLog((XCODE_COLORS_ESCAPE @"fg255,0,0;%s+%d " frmt XCODE_COLORS_RESET),__func__,__LINE__, ##__VA_ARGS__)
#else
#define MCLogInfo(frmt, ...)
#define MCLogWarn(frmt, ...)
#define MCLogError(frmt, ...)
#define NSLog(...)
#endif

@protocol MCWSStreamDelegate;

@interface MCWSStream : NSObject

/**
 开启WebSocket服务

 @param delegate 代理
 @param wsport 端口
 */
- (void)startWithDelegate:(id<MCWSStreamDelegate>)delegate port:(UInt16)wsport;

@end

@protocol MCWSStreamDelegate <NSObject>

- (void)webSocket:(MCWSStream *)steam didHandshake:(BOOL)result;

- (void)webSocket:(MCWSStream *)steam didReceiveMessage:(NSString *)message;

@end
