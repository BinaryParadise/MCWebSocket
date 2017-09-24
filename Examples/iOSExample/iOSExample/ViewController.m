//
//  ViewController.m
//  iOSExample
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "ViewController.h"

@import MCWebSocket;
@import SocketRocket;

@interface ViewController () <SRWebSocketDelegate> {
    SRWebSocket *_srweb;
}

@property (nonatomic, strong) MCWSStream *wsStream;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.wsStream = [[MCWSStream alloc] init];
    [self.wsStream startWithPort:1688];
    
    _srweb = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:@"http://192.168.2.27:1688"]];
    _srweb.delegate = self;
    //[_srweb open];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"%@", message);
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [webSocket send:@"send message with websocket."];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
