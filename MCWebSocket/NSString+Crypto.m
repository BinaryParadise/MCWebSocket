//
//  NSObject+Crypto.m
//  MCWebSocket
//
//  Created by mylcode on 2017/9/23.
//  Copyright © 2017年 mylcode. All rights reserved.
//

#import "NSString+Crypto.h"
#import <CommonCrypto/CommonDigest.h>
@import GTMBase64;

@implementation NSString (Crypto)

- (instancetype)sha1AndBase64String {
    return newSHA1String(self.UTF8String, self.length);
}

static NSString *newSHA1String(const char *bytes, size_t length) {
    uint8_t md[CC_SHA1_DIGEST_LENGTH];
    
    assert(length >= 0);
    assert(length <= UINT32_MAX);
    CC_SHA1(bytes, (CC_LONG)length, md);
    
    NSData *data = [NSData dataWithBytes:md length:CC_SHA1_DIGEST_LENGTH];
    
    return [data base64EncodedStringWithOptions:0];
}

- (instancetype)base64 {
    NSData *base64Data = [NSData dataWithBytes:self.UTF8String length:self.length];
    return [base64Data base64EncodedStringWithOptions:0];
}

@end
