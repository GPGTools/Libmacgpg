//
//  GPGMemoryStream.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGMemoryStream.h"

@interface GPGMemoryStream ()
// might be called (internally) for a writeable stream after writing
- (void)openForReading;
@end

@implementation GPGMemoryStream

- (void)dealloc 
{
    [_data release];
    [_readableData release];
    [super dealloc];
}

- (id)init 
{
    if (self = [super init]) {
        _data = [[NSMutableData data] retain];
        // _readableData stays nil
    }
    return self;
}

- (id)initForReading:(NSData *)data
{
    if (self = [super init]) {
        // _data stays nil
        _readableData = [data retain];
    }
    return self;
}

+ (id)memoryStream 
{
    return [[[self alloc] init] autorelease];
}

+ (id)memoryStreamForReading:(NSData *)data
{
    return [[[self alloc] initForReading:data] autorelease];
}

- (void)writeData:(NSData *)data
{
    if (!_data)
        @throw [NSException exceptionWithName:@"InvalidOperationException" reason:@"stream is readable" userInfo:nil];
    [_data appendData:data];
}

- (NSData *)readDataToEndOfStream
{
    if (!_readableData) 
        [self openForReading];

    unsigned long long rlength = [_readableData length];
    if (_readPos >= rlength)
        return [NSData data];

    NSData *result = [_readableData subdataWithRange:NSMakeRange(_readPos, rlength - _readPos)];
    _readPos = rlength;
    return result;
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
    if (!_readableData) 
        [self openForReading];
        
    unsigned long long rlength = [_readableData length];
    if (_readPos >= rlength)
        return [NSData data];

    NSUInteger nextLength = MIN(length, rlength - _readPos);
    NSData *result = [_readableData subdataWithRange:NSMakeRange(_readPos, nextLength)];
    _readPos += nextLength;
    return result;
}

- (NSData *)readAllData 
{
    if (!_readableData)
        [self openForReading];

    return [[_readableData retain] autorelease];
}

- (char)peekByte 
{
    if (!_readableData)
        [self openForReading];

    unsigned long long rlength = [_readableData length];
    if (_readPos >= rlength)
        return 0;

    char buf[1] = {0};
    [_readableData getBytes:&buf range:NSMakeRange(_readPos, 1)];
    return buf[0];
}

/// flush does nothing special

/// close does nothing special

- (void)seekToBeginning
{
    if (_data)
        [_data setLength:0];
    if (_readableData) 
        _readPos = 0;
}

- (unsigned long long)length
{
    if (_readableData)
        return [_readableData length];
    return [_data length];
}

#pragma mark - private

- (void)openForReading 
{
    if (!_readableData) 
        _readableData = [[NSData dataWithData:_data] retain];
    if (_data) {
        [_data release];
        _data = nil;
    }
}

@end
