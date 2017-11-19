//
//  MCDBViewController.m
//  MCWebSocket_Example
//
//  Created by mylcode on 2017/11/19.
//  Copyright © 2017年 MC-Studio. All rights reserved.
//

#import "MCDBViewController.h"
#import "MCDBStream.h"

@interface MCDBViewController () <MCWSStreamDelegate>

@property (nonatomic, strong) MCDBStream *dbStream;

@end

@implementation MCDBViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.dbStream = [[MCDBStream alloc] init];
    [self.dbStream startWithDelegate:nil port:1688];
    
    [self registerDBService];
}

- (void)registerDBService {
    NSMutableURLRequest *mreq = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://127.0.0.1:8080/db/register"]];
    mreq.HTTPMethod = @"POST";
    //x-www-form-urlencoded
    NSMutableString *mstr = [NSMutableString string];
    [mstr appendFormat:@"deviceId=%@", [[UIDevice currentDevice] identifierForVendor].UUIDString];
    [mreq setHTTPBody:[mstr dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:mreq];
    [task resume];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
