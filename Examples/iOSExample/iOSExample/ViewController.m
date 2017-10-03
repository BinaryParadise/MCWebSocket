//
//  ViewController.m
//  iOSExample
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "ViewController.h"

@import MCWebSocket;
@import FMDB;
@import MCJSONKit;

@interface ViewController () <MCWSStreamDelegate> {
    FMDatabaseQueue *_dbQueue;
}

@property (nonatomic, strong) MCWSStream *wsStream;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.wsStream = [[MCWSStream alloc] init];
    [self.wsStream startWithDelegate:self port:1688];
    
    [self createDatabase];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/**
 创建测试数据库
 */
- (void)createDatabase {
    MCLogMark(@"%@", NSHomeDirectory());
    NSString *dbPath = [NSHomeDirectory() stringByAppendingString:@"/Documents/websocket.sqlite"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
        FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
        [db open];
        [db executeStatements:@"CREATE TABLE \"main\".\"CallLog\" (\n\t \"id\" INTEGER NOT NULL,\n\t \"time\" integer,\n\t \"sql\" TEXT,\n\tPRIMARY KEY(\"id\")\n);\n\nINSERT INTO \"CallLog\" VALUES (1, strftime('%s', 'now'), \'CREATE TABLE \"main\".\"CallLog\" (\n\t \"id\" INTEGER NOT NULL,\n\t \"time\" integer,\n\t \"sql\" TEXT,\n\tPRIMARY KEY(\"id\")\n);\');"];
        [db close];
    }
    
    _dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
}

#pragma mark - MCWSStreamDelegate

- (void)webSocket:(MCWSStream *)stream didHandshake:(BOOL)result {
    MCLogInfo(@"握手成功");
}

- (void)webSocket:(MCWSStream *)stream didReceiveMessage:(NSString *)message withTag:(long)tag {
    [_dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableDictionary *mdict = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(0), @"code", nil];
        @try {
            [db executeUpdate:@"insert into CallLog(time,sql) values(?,?)", @([NSDate date].timeIntervalSince1970), message];
            FMResultSet *rs = [db executeQuery:message];
            NSMutableArray *marr = [NSMutableArray array];
            while ([rs next]) {
                if (marr.count == 0) {
                    NSMutableArray *columns = [NSMutableArray array];
                    for (int i=0; i < rs.columnCount; i++) {
                        [columns addObject:[rs columnNameForIndex:i]];
                    }
                    [marr addObject:columns];
                }
                
                NSMutableArray *dataArr = [NSMutableArray array];
                for (int i=0; i < rs.columnCount; i++) {
                    [dataArr addObject:[rs objectForColumnIndex:i]];
                }
            
                [marr addObject:dataArr];
            }
            [mdict setObject:marr forKey:@"data"];
        } @catch (NSException *exception) {
            [mdict setObject:exception.reason forKey:@"msg"];
            [mdict setObject:@(-1) forKey:@"code"];
        } @finally {
            [stream sendMessage:mdict.mc_JSONString withTag:tag];
        }
    }];
}


@end
