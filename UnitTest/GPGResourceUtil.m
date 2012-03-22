//
//  GPGResourceUtil.m
//  Libmacgpg
//
//  Created by Chris Fraire on 3/22/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGResourceUtil.h"

@implementation GPGResourceUtil

+ (NSData *)dataForResourceAtPath:(NSString *)path ofType:(NSString *)rtype {
    NSBundle *execBundl = [NSBundle bundleForClass:[self class]];
    NSString *file = [execBundl pathForResource:path ofType:rtype];
    NSData *data = [NSData dataWithContentsOfFile:file];
    if (!data)
        @throw [NSException exceptionWithName:@"ApplicationException" reason:@"missing resource" userInfo:nil];
    return data;
}

@end
