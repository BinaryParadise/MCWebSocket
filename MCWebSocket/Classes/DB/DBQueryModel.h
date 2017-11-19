//
//  DBQueryModel.h
//  CocoaAsyncSocket
//
//  Created by mylcode on 2017/11/19.
//

#import <Foundation/Foundation.h>
#import "MCJSONKit.h"

typedef enum : NSUInteger {
    DBFileList, //沙盒中数据库文件列表
    DBExecuteCmd //执行数据库查询脚本
} DBQueryType;

@interface DBQueryModel : NSObject

@property (nonatomic, assign) DBQueryType type;

/**
 数据库路径
 */
@property (nonatomic, copy) NSString *dbPath;

/**
 需要执行的SQL脚本
 */
@property (nonatomic, copy) NSString *sqlCommand;

@end
