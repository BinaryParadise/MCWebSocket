//
//  MCDBStream.m
//  MCWebSocket
//
//  Created by mylcode on 2017/11/4.
//

#import "MCDBStream.h"
#import "FMDB.h"
#import "DBQueryModel.h"

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
    
    if (!_dbQueue || ![dbPath isEqualToString:_dbQueue.path]) {
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

- (void)fetchAllDBFiles:(long)tag {
    NSString *curPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSMutableDictionary *mdict = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(0), @"code", nil];
    NSMutableArray *marr = [NSMutableArray array];
    for (NSString *name in [[NSFileManager defaultManager] enumeratorAtPath:curPath]) {
        if ([name hasSuffix:@".db"] || [name hasSuffix:@".sqlite"]) {
            MCLogDebug(@"%@", name);
            [marr addObject:name];
        }
    }
    
    [mdict setObject:marr forKey:@"data"];
    
    [self sendMessage:[mdict mc_JSONString] withTag:tag];
}

- (void)executeCommand:(DBQueryModel *)model tag:(long)tag {
    self.dbPath = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@",model.dbPath];
    [_dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableDictionary *mdict = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(0), @"code", nil];
        @try {
            [db executeUpdate:@"insert into CallLog(time,sql) values(?,?)", @([NSDate date].timeIntervalSince1970), model.sqlCommand];
            FMResultSet *rs = [db executeQuery:model.sqlCommand];
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
            [self sendMessage:mdict.mc_JSONString withTag:tag];
        }
    }];
}
    
#pragma mark - MCWSStreamDelegate
    
- (void)webSocket:(MCWSStream *)stream didHandshake:(BOOL)result {
    MCLogInfo(@"握手成功");
}
    
- (void)webSocket:(MCWSStream *)stream didReceiveMessage:(NSString *)message withTag:(long)tag {
    DBQueryModel *queryModel = [DBQueryModel co_objectFromKeyValues:message];
    if (queryModel) {
        if (queryModel.type == DBFileList) {
            [self fetchAllDBFiles:tag];
        }else if (queryModel.type == DBExecuteCmd) {
            [self executeCommand:queryModel tag:tag];
        }
    }
}

@end
