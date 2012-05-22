//
//  GPGStream.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGStream.h"

@implementation GPGStream

- (void)writeData:(NSData *)data {
    // nothing
}

- (NSData *)readDataToEndOfStream {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];
}

- (NSData *)readAllData {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];
}

- (char)peekByte {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];
}

- (void)close {
    // nothing
}

- (void)flush {
    // nothing
}

- (void)seekToBeginning {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];    
}

- (unsigned long long)length {
    @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"abstract method" userInfo:nil];
}

@end
