//
//  ViewController.m
//  iOSExample
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "ViewController.h"

@import MCWebSocket;

@interface ViewController () <MCWSStreamDelegate>

@property (nonatomic, strong) MCWSStream *wsStream;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.wsStream = [[MCWSStream alloc] init];
    [self.wsStream startWithDelegate:self port:1688];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - MCWSStreamDelegate

- (void)webSocket:(MCWSStream *)steam didHandshake:(BOOL)result {
    MCLogInfo(@"握手成功");
}

- (void)webSocket:(MCWSStream *)steam didReceiveMessage:(NSString *)message {
    MCLogInfo(@"%@", message);
}


@end
