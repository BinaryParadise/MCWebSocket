//
//  MCDBStream.m
//  MCWebSocket
//
//  Created by mylcode on 2017/11/4.
//

#import "MCDBStream.h"
#import "FMDB.h"
#import "MCJSONKit.h"

@interface MCDBStream () <MCWSStreamDelegate>
    
@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
    
@end

@implementation MCDBStream
    
- (void)startWithDelegate:(id<MCWSStreamDelegate>)delegate port:(UInt16)wsport {
    [super startWithDelegate:delegate?delegate:self port:wsport];
    
    [self createDatabase];
}

- (void)setDbPath:(NSString *)dbPath {
    _dbPath = dbPath;
    
    if (!_dbQueue) {
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbPath];
    }
}

/**
 创建测试数据库
 */
- (void)createDatabase {
    MCLogDebug(@"%@", NSHomeDirectory());
    if (!self.dbPath) {
        self.dbPath = [NSHomeDirectory() stringByAppendingString:@"/Documents/websocket.sqlite"];
    }

    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeStatements:@"CREATE TABLE \"main\".\"CallLog\" (\n\t \"id\" INTEGER NOT NULL,\n\t \"time\" integer,\n\t \"sql\" TEXT,\n\tPRIMARY KEY(\"id\")\n);\n\nINSERT INTO \"CallLog\" VALUES (1, strftime('%s', 'now'), \'CREATE TABLE \"main\".\"CallLog\" (\n\t \"id\" INTEGER NOT NULL,\n\t \"time\" integer,\n\t \"sql\" TEXT,\n\tPRIMARY KEY(\"id\")\n);\');"];
    }];
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
