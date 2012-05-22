//
//  GPGFileStream.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/21/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GPGFileStream.h"

@interface GPGFileStream ()
// might be called (internally) for a writeable stream after writing
- (void)openForReading;
@end

@implementation GPGFileStream

- (void)dealloc
{
    [_filepath release];
    [_fh release];
    [_readfh release];
    [super dealloc];
}

- (id)init {
    return [self initForWritingAtPath:nil error:nil];
}

+ (id)fileStreamForWritingAtPath:(NSString *)path {
    NSError *error = nil;
    id newObject = [[[self alloc] initForWritingAtPath:path error:&error] autorelease];
    if (error)
        return nil;
    return newObject;
}

+ (id)fileStreamForReadingAtPath:(NSString *)path {
    NSError *error = nil;
    id newObject = [[[self alloc] initForReadingAtPath:path error:&error] autorelease];
    if (error)
        return nil;
    return newObject;
}

- (id)initForWritingAtPath:(NSString *)path error:(NSError **)error
{
    if (self = [super init]) {
        _filepath = [path retain];

        if (path) {
            _fh = [[NSFileHandle fileHandleForWritingAtPath:path] retain];

            if (!_fh) {
                if (error)
                    *error = [NSError errorWithDomain:@"libc" code:0 userInfo:nil];
            }
        }
        else {
            _fh = [[NSFileHandle fileHandleWithNullDevice] retain];
        }
    }

    return self;
}

- (id)initForReadingAtPath:(NSString *)path error:(NSError **)error
{
    if (self = [super init]) {
        _filepath = [path retain];

        if (path) {
            [self openForReading];
            if (!_readfh) {
                if (error)
                    *error = [NSError errorWithDomain:@"libc" code:0 userInfo:nil];
            }
        }
        else {
            _readfh = [[NSFileHandle fileHandleWithNullDevice] retain];
        }
    }
    
    return self;
}

- (void)writeData:(NSData *)data 
{
    if (_readfh)
        @throw [NSException exceptionWithName:@"InvalidOperationException" reason:@"stream is readable" userInfo:nil];
    [_fh writeData:data];
}

- (NSData *)readDataToEndOfStream
{
    if (!_readfh)
        [self openForReading];
    return [_readfh readDataToEndOfFile];
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    if (!_readfh)
        [self openForReading];
    return [_readfh readDataOfLength:length];
}

- (NSData *)readAllData {
    if (!_readfh) 
        [self openForReading];
    [_readfh seekToFileOffset:0];
    return [_readfh readDataToEndOfFile];
}

- (char)peekByte {
    if (!_readfh)
        [self openForReading];

    unsigned long long currentPos = [_readfh offsetInFile];
    NSData *peek = [_readfh readDataOfLength:1];
    [_readfh seekToFileOffset:currentPos];

    if (peek && [peek length])
        return *(char *)[peek bytes];
    return 0;
}

- (void)close 
{
    [_fh closeFile];
    if (_readfh) {
        [_readfh closeFile];
        // release and nil so it could be re-opened if necessary
        [_readfh release];
        _readfh = nil;
    }
}

- (void)flush {
    [_fh synchronizeFile];
}

- (void)seekToBeginning 
{
    if (_fh) {
        [_fh truncateFileAtOffset:0];
    }
    if (_readfh) {
        [_readfh seekToFileOffset:0];
    }
}

- (unsigned long long)length
{
    if (_readfh)
        return _flength;
    return [_fh offsetInFile];
}

#pragma mark - private

- (void)openForReading 
{
    if (_fh) {
        [_fh closeFile];
        [_fh release];
        _fh = nil;
    }
    if (!_readfh)
    {
        _readfh = [[NSFileHandle fileHandleForReadingAtPath:_filepath] retain];
        _flength = [_readfh seekToEndOfFile];
        [_readfh seekToFileOffset:0];
    }
}

@end
