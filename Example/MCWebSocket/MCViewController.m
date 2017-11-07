//
//  MCViewController.m
//  MCWebSocket
//
//  Created by mylcode on 11/04/2017.
//  Copyright (c) 2017 mylcode. All rights reserved.
//

#import "MCViewController.h"
#import <WebKit/WebKit.h>
#import "MCLogStream.h"

@interface MCViewController ()
    
@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic, strong) MCLogStream *dbStream;

@end

@implementation MCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.dbStream = [[MCLogStream alloc] init];
    [self.dbStream startWithDelegate:nil port:1688];
    
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"websocket.html" ofType:nil];
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.webView];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlFile]]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
