//
//  MCViewController.m
//  MCWebSocket
//
//  Created by mylcode on 11/04/2017.
//  Copyright (c) 2017 mylcode. All rights reserved.
//

#import "MCViewController.h"
#import <WebKit/WebKit.h>
#import "MCWSStream.h"

@interface MCViewController () <MCWSStreamDelegate> {
    NSInteger logCount;
}
    
@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic, strong) MCWSStream *dbStream;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) NSArray *logs;

@end

@implementation MCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.dbStream = [[MCWSStream alloc] init];
    [self.dbStream startWithDelegate:self port:1688];
    
    self.timer = [NSTimer timerWithTimeInterval:0.2 target:self selector:@selector(tickAction:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    self.logs = @[@{@"level":@(1), @"msg":@"普通信息"},
                  @{@"level":@(2), @"msg":@"警告信息"},
                  @{@"level":@(3), @"msg":@"调试信息，比较醒目"},
                  @{@"level":@(4), @"msg":@"错误信息，特别醒目"}];
}

- (void)tickAction:(NSTimer *)sender {
    NSMutableDictionary<NSString *, NSString *> *logDict = [self.logs[arc4random()%4] mutableCopy];
    NSString *msg = [NSString stringWithFormat:@"[%zd]%@", logCount++, logDict[@"msg"]];
    logDict[@"msg"] = msg;
    switch ([logDict[@"level"] intValue]) {
        case 2:
            MCLogWarn(@"%@", msg)
            break;
        case 3:
            MCLogDebug(@"%@", msg)
            break;
        case 4:
            MCLogError(@"%@", msg)
            break;
        default:
            MCLogInfo(@"%@", msg)
            break;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:logDict options:NSJSONWritingPrettyPrinted error:nil];
    
    [self.dbStream sendData:data withTag:0];
}

- (void)webSocket:(MCWSStream *)stream didHandshake:(BOOL)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timer fire];
    });
}

@end
