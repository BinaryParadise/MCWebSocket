//
//  MCDBStream.h
//  MCWebSocket
//
//  Created by mylcode on 2017/11/4.
//

#import "MCWSStream.h"

@interface MCDBStream : MCWSStream

/**
 数据库路径，默认为~/Document/websocket.sqlite
 */
@property (nonatomic, copy) NSString *dbPath;
    
@end
