/* GPGTaskHelper created by Lukas Pitschl (@lukele) on Thu 02-Jun-2012 */

/*
 * Copyright (c) 2000-2012, GPGTools Project Team <gpgtools-org@lists.gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Project Team nor the names of GPGMail
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Project Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <xpc/xpc.h>
#import <XPCKit/XPCKit.h>
#import "GPGOptions.h"
#import "GPGGlobals.h"
#import "GPGTaskHelper.h"
#import "GPGMemoryStream.h"
#import "LPXTTask.h"
#import "NSPipe+NoSigPipe.h"
#import "GPGException.h"

static const NSUInteger kDataBufferSize = 65536; 

typedef void (^basic_block_t)(void);

/**
 Helper method to run a block and intercept any exceptions.
 Copies the exceptions into the given blockException reference.
 */
void runBlockAndRecordExceptionSynchronizedWithHandlers(basic_block_t run_block, basic_block_t catch_block, basic_block_t finally_block, NSObject **lock, NSException **blockException) {
    
    @try {
        run_block();
    }
    @catch (NSException *exception) {
        @synchronized(*lock) {
            *blockException = [exception retain];
        }
        if(catch_block)
            catch_block();
    }
    @finally {
        if(finally_block)
            finally_block();
    }
}

void runBlockAndRecordExceptionSyncronized(basic_block_t run_block, NSObject **lock, NSException **blockException) {
    runBlockAndRecordExceptionSynchronizedWithHandlers(run_block, NULL, NULL, lock, blockException);
}

/**
 Runs a block within a sub autorelease pool.
 */
void withAutoreleasePool(basic_block_t block)
{
    NSAutoreleasePool *pool = nil;
    @try {
        pool = [[NSAutoreleasePool alloc] init];
        block();
    }
    @catch (NSException *exception) {
        @throw exception;
    }
    @finally {
        [pool release];
    }
}

@interface GPGTaskHelper ()

@property (nonatomic, retain, readwrite) NSData *status;
@property (nonatomic, retain, readwrite) NSData *errors;
@property (nonatomic, retain, readwrite) NSData *attributes;
@property (nonatomic, readonly) LPXTTask *task;
@property (nonatomic, retain) NSDictionary *userIDHint;
@property (nonatomic, retain) NSDictionary *needPassphraseInfo;
@property (nonatomic, readonly) XPCConnection *sandboxHelper;

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close;

@end

@implementation GPGTaskHelper

@synthesize inData = _inData, arguments = _arguments, output = _output,
processStatus = _processStatus, task = _task, exitStatus = _exitStatus, status = _status, errors = _errors, attributes = _attributes, readAttributes = _readAttributes, progressHandler = _progressHandler, userIDHint = _userIDHint, needPassphraseInfo = _needPassphraseInfo, checkForSandbox = _checkForSandbox, sandboxHelper = _sandboxHelper;

+ (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/bin", @"/usr/local/MacGPG2/bin", @"/usr/local/MacGPG1/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *searchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
		if (foundPath) {
			return foundPath;
		}		
	}
	
	return nil;
}
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths {
	NSString *searchPath, *foundPath;
	for (searchPath in paths) {
		foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return [foundPath stringByStandardizingPath];
		}
	}
	return nil;
}

+ (NSString *)GPGPath {
    static NSString *GPGPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GPGPath = [GPGTaskHelper findExecutableWithName:@"gpg2"];
        if(!GPGPath)
            GPGPath = [GPGTaskHelper findExecutableWithName:@"gpg"];
        [GPGPath retain];
    });
    return GPGPath;
}

+ (NSString *)pinentryPath {
    static NSString *pinentryPath = nil;
    static dispatch_once_t pinentryToken;
    dispatch_once(&pinentryToken, ^{
        // Checking in order:
        // 1. pinentry-mac in a bundle named "org.gpgtools.Libmacgpg" 
        // 2. a defined "pinentry-program" in gpg-agent.conf
        // 3. a pinentry-mac executable in a set of dirs (e.g., /usr/local/bin) 
        //
        NSMutableArray *possibleBins = [NSMutableArray array];
        NSFileManager *fmgr = [NSFileManager defaultManager];
        
        // 1.
        NSString *bndlePath = [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] 
                               pathForResource:@"pinentry-mac" ofType:@"" 
                               inDirectory:@"pinentry-mac.app/Contents/MacOS"];
        if (bndlePath && [fmgr isExecutableFileAtPath:bndlePath]) 
            [possibleBins addObject:bndlePath];
        
        // 2.
        static NSString * const kPinentry_program = @"pinentry-program";
        GPGOptions *options = [GPGOptions sharedOptions];
        NSString *inconfPath = [options valueForKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
        inconfPath = [inconfPath stringByStandardizingPath];
        if (inconfPath && [fmgr isExecutableFileAtPath:inconfPath]) 
            [possibleBins addObject:inconfPath];
        else
            inconfPath = nil;
        
        // 3. Per mento: this feature is a rescue and update system 
        // if the user doesn't use MacGPG2
        if (!inconfPath) {
            if ([possibleBins count] < 1) {
                inconfPath = [self findExecutableWithName:@"../libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac"];
                if (inconfPath)
                    [possibleBins addObject:inconfPath];
            }
            
            if ([possibleBins count] > 0) {
                inconfPath = [possibleBins objectAtIndex:0];
                [options setValue:inconfPath forKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
                [options gpgAgentTerminate];
            }
        }
        
        NSString *foundPath = ([possibleBins count] > 0) ? [possibleBins objectAtIndex:0] : nil;
        if (foundPath)
            pinentryPath = [foundPath retain];
    });
	return pinentryPath;
}


- (id)initWithArguments:(NSArray *)arguments {
    self = [super init];
    if(self) {
        _arguments = [arguments copy];
        _processedBytesMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSUInteger)_run {
    _task = [[LPXTTask alloc] init];
    _task.launchPath = [GPGTaskHelper GPGPath];
    _task.arguments = self.arguments;
    
    if(!_task.launchPath)
        @throw [GPGException exceptionWithReason:@"GPG not found!" errorCode:GPGErrorNotFound];
    
#ifdef DEBUG
    NSLog(@"$> %@ %@", _task.launchPath, [_task.arguments componentsJoinedByString:@" "]);
#endif
    
    // Create read pipes for status and attribute information.
    [_task inheritPipeWithMode:O_RDONLY dup:3 name:@"status"];
    [_task inheritPipeWithMode:O_RDONLY dup:4 name:@"attribute"];
    
    // Create write pipes for the data to pass in.
    __block NSMutableArray *dupList = [[NSMutableArray alloc] init];
    __block int i = 5;
    __block NSUInteger totalData = 0;
    [self.inData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [dupList addObject:[NSNumber numberWithInt:i++]];
        totalData += [obj length];
    }];
    _totalInData = totalData;
    [_task inheritPipesWithMode:O_WRONLY dups:dupList name:@"ins"];
    [dupList release];
    
    __block NSException *blockException = nil;
    __block typeof(self) object = self;
    __block NSData *stderrData = nil;
    __block NSData *statusData = nil;
    __block NSData *attributeData = nil;
    
    __block NSObject *lock = [[[NSObject alloc] init] autorelease];
    
    _task.parentTask = ^{
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        dispatch_group_t collectorGroup = dispatch_group_create();
        
        // The data is written to the pipe as soon as gpg issues the status
        // BEGIN_ENCRYPTION or BEGIN_SIGNING. See processStatus.
        // When we want to encrypt or sign, the data can't be written before the 
		// BEGIN_ENCRYPTION or BEGIN_SIGNING status was issued, BUT
        // in every other case, gpg stalls till it received the data to decrypt.
        // So in that case, the data actually has to be written as the very first thing.
        
        NSArray *options = [NSArray arrayWithObjects:@"--encrypt", @"--sign", @"--clearsign", @"--detach-sign", @"--symmetric", @"-e", @"-s", @"-b", @"-c", nil];
        
        if([self.arguments firstObjectCommonWithArray:options] == nil) {
            dispatch_group_async(collectorGroup, queue, ^{
                runBlockAndRecordExceptionSyncronized(^{
                    [object writeInputData];
                }, &lock, &blockException);
            });
        }
        
        dispatch_group_async(collectorGroup, queue, ^{
            runBlockAndRecordExceptionSyncronized(^{
                NSData *data;
                while((data = [[[object.task inheritedPipeWithName:@"stdout"] fileHandleForReading] readDataOfLength:kDataBufferSize]) &&  [data length] > 0) {
                    withAutoreleasePool(^{
                        [self.output writeData:data];
                    });
                }
            }, &lock, &blockException);
        });
        
        dispatch_group_async(collectorGroup, queue, ^{
            runBlockAndRecordExceptionSyncronized(^{
                stderrData = [[[[object.task inheritedPipeWithName:@"stderr"] fileHandleForReading] readDataToEndOfFile] retain];
            }, &lock, &blockException);
        });
        
        if(self.readAttributes) {
            // Optionally get attribute data.
            dispatch_group_async(collectorGroup, queue, ^{
                runBlockAndRecordExceptionSyncronized(^{
                    attributeData = [[[[object.task inheritedPipeWithName:@"attribute"] fileHandleForReading] readDataToEndOfFile] retain];
                }, &lock, &blockException);
            });
        }
        
        dispatch_group_async(collectorGroup, queue, ^{
            runBlockAndRecordExceptionSynchronizedWithHandlers(^{
                statusData = [[object parseStatusLines] retain];
            }, ^{
                [object cancel];
            }, NULL, &lock, &blockException);
        });
        
        // Wait for all jobs to complete.
        dispatch_group_wait(collectorGroup, DISPATCH_TIME_FOREVER);
        
        dispatch_release(collectorGroup);
        dispatch_release(queue);
    };
    
    [_task launchAndWait];
    
    if(blockException)
        @throw blockException;
    
    self.status = statusData;
    self.errors = stderrData;
    self.attributes = attributeData;
    
    _exitStatus = _task.terminationStatus;
    
    if(_cancelled)
        _exitStatus = GPGErrorCancelled;
    
    return _exitStatus;
}

- (NSUInteger)_runInSandbox {
    // The semaphore is used to wait for the reply from the xpc
    // service.
    if(!_sandboxHelper) {
        _sandboxHelper = [[XPCConnection alloc] initWithServiceName:@"org.gpgtools.Libmacgpg.GPGTaskHelper"];
    }
    
#ifdef USE_XPCSERVICE
    NSLog(@"[%@] gpg2 %@", _sandboxHelper, [self.arguments componentsJoinedByString:@" "]);
#endif

    __block typeof(self) this = self;
    
    _sandboxHelper.eventHandler = ^(XPCMessage *message, XPCConnection *inConnection){
        NSString *action = [message objectForKey:@"action"];
        
        if([action isEqualToString:@"status"]) {
            NSData *response = self.processStatus([message objectForKey:@"keyword"], [message objectForKey:@"value"]);
            XPCMessage *reply = [XPCMessage messageReplyForMessage:message];
            NSLog(@"Response: %@", response);
            if(response)
                [reply setObject:response forKey:@"response"];
            
            [this.sandboxHelper sendMessage:reply];
        }
        else if([action isEqualToString:@"progress"]) {
            this.progressHandler([[message objectForKey:@"processedBytes"] intValue], [[message objectForKey:@"totalBytes"] intValue]);
        }
    };
	
    // GPGStream has to be converted to NSData first.
    NSMutableArray *convertedInData = [NSMutableArray array];
    [self.inData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [convertedInData addObject:[obj readAllData]];
    }];
    
    __block NSException *connectionError = nil;
    __block NSException *taskHelperException = nil;
    [_sandboxHelper sendMessage:[XPCMessage messageWithObjectsAndKeys:@"new", @"action", self.arguments, @"arguments", convertedInData, @"data", [NSNumber numberWithBool:self.readAttributes], @"readAttributes", nil] withReply:^(XPCMessage *message) {
        if([message objectForKey:@"exception"]) {
            taskHelperException = [message objectForKey:@"exception"];
            return;
        }
        this.status = [message objectForKey:@"status"];
        this.attributes = [message objectForKey:@"attributes"];
        this.errors = [message objectForKey:@"errors"];
        this.exitStatus = [[message objectForKey:@"exitcode"] intValue];
        if([message objectForKey:@"output"])
            [this.output writeData:[message objectForKey:@"output"]];
    } errorHandler:^(NSError *error) {
        NSString *explanation = nil;
        if(error.code == XPCConnectionInterrupted)
            explanation = @"GPGTaskHelper failed to complete task.";
        else if(error.code == XPCConnectionInvalid)
            explanation = @"Failed to connect to GPGTaskHelper. Check service name.";
        
        connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
    } wait:YES];
    
    if(connectionError)
        @throw connectionError;
    
    if(taskHelperException)
        @throw taskHelperException;
    
    return self.exitStatus;
}

- (NSUInteger)run {
#ifdef USE_XPCSERVICE
    _sandboxed = USE_XPCSERVICE ? YES : NO;
#else
    NSBundle *bundle = [NSBundle mainBundle];
    _sandboxed = [bundle ob_isSandboxed];
#endif
    
    if(self.checkForSandbox && _sandboxed)
        return [self _runInSandbox];
    else
        return [self _run];
}

- (void)writeInputData {
    if(!_task || !self.inData) return;
    
    NSArray *pipeList = [self.task inheritedPipesWithName:@"ins"];
    [pipeList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self writeData:[self.inData objectAtIndex:idx] pipe:obj close:YES];
    }];
    
    self.inData = nil;
}

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close {
    NSFileHandle *ofh = [pipe fileHandleForWriting];
    GPGStream *input = data;
    NSData *tempData = nil;
    
    @try {
        while((tempData = [input readDataOfLength:kDataBufferSize]) && 
              [tempData length] > 0) {
            withAutoreleasePool(^{ 
                [ofh writeData:tempData]; 
            });
        }
        
        if(close)
            [ofh closeFile];
    }
    @catch (NSException *exception) {
        @throw exception;
        return;
    }
}

- (NSData *)parseStatusLines {
    NSMutableString *line = [NSMutableString string];
    NSPipe *statusPipe = [self.task inheritedPipeWithName:@"status"];
    
    NSData *currentData = nil;
    NSMutableData *statusData = [NSMutableData data]; 
    NSData *NL = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
    while((currentData = [[statusPipe fileHandleForReading] availableData])&& [currentData length]) {
        [statusData appendData:currentData];
        [line appendString:[[[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding] autorelease]];
        // Skip data without line ending. Not a full line!
        if([currentData rangeOfData:NL options:NSDataSearchBackwards range:NSMakeRange(0, [currentData length])].location == NSNotFound)
            continue;
        
        // If a line ending is found, it's possible that the data contains
        // multiple lines.
        NSArray *lines = [line componentsSeparatedByString:@"\n"];
        [lines enumerateObjectsUsingBlock:^(id currentLine, NSUInteger idx, BOOL *stop) {
            // The last line might not be complete. If that's the case,
            // further incoming data is appended to that line until
            // the line is complete (has a new line).
            if(idx == [lines count] - 1) {
                // Check for a new line.
                NSString *newLine = @"";
                if([currentLine length] != 0)
                    newLine = [currentLine substringWithRange:NSMakeRange([currentLine length] - 1, [currentLine length])];
                if(![newLine isEqualToString:@"\n"]) {
                    [line setString:currentLine];
                    return;
                }
                [line setString:@""];
            }
            
            // Split line in keyword and value.
            NSString *keyword, *value = @"";
            
            NSMutableArray *parts = [[[[currentLine stringByReplacingOccurrencesOfString:@"\n" withString:@""]stringByReplacingOccurrencesOfString:GPG_STATUS_PREFIX withString:@""] componentsSeparatedByString:@" "] mutableCopy];
            
            keyword = [parts objectAtIndex:0];
            [parts removeObjectAtIndex:0];
            value = [parts componentsJoinedByString:@" "];
            
            [parts release];
            [self processStatusWithKeyword:keyword value:value];
        }];
    }
    return statusData;
}

- (void)processStatusWithKeyword:(NSString *)keyword value:(NSString *)value {
    
    NSUInteger errorCode;
    NSInteger code = [[[[self class] statusCodes] objectForKey:keyword] integerValue];
    if(!code)
        return;
    
    NSLog(@"[GNUPG]: %@ %@", keyword, value);
    // Most keywords are handled by the processStatus callback,
    // but some like pinentry passphrase requests are handled
    // directly.
    
    switch(code) {
        case GPG_STATUS_USERID_HINT: {
            NSRange range = [value rangeOfString:@" "];
            NSString *keyID = [value substringToIndex:range.location];
            NSString *userID = [value substringFromIndex:range.location + 1];
            self.userIDHint = [NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", userID, @"userID", nil];
            break;
        }
        case GPG_STATUS_NEED_PASSPHRASE: {
            NSArray *components = [value componentsSeparatedByString:@" "];
            self.needPassphraseInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [components objectAtIndex:0], @"mainKeyID", 
                                       [components objectAtIndex:1], @"keyID", 
                                       [components objectAtIndex:2], @"keyType", 
                                       [components objectAtIndex:3], @"keyLength", nil];
            break;
        }
        case GPG_STATUS_GOOD_PASSPHRASE:
        case GPG_STATUS_BAD_PASSPHRASE:
        case GPG_STATUS_MISSING_PASSPHRASE: {    
            self.userIDHint = nil;
            self.needPassphraseInfo = nil;
            if(code == GPG_STATUS_MISSING_PASSPHRASE)
                errorCode = GPGErrorCancelled;
            break;
        }
        case GPG_STATUS_GET_LINE:
        case GPG_STATUS_GET_BOOL:
        case GPG_STATUS_GET_HIDDEN:
            if([value isEqualToString:@"passphrase.enter"])
                [self getPassphraseAndForward];
            else {
                NSData *response = self.processStatus(keyword, value);
                if(response)
                    [self replyToCommand:response];
            }
            break;
            
        case GPG_STATUS_BEGIN_ENCRYPTION:
        case GPG_STATUS_BEGIN_SIGNING:
            [self writeInputData];
            break;
            
        case GPG_STATUS_PROGRESS: {
            if (!_totalInData)
                break;
            
            NSArray *parts = [value componentsSeparatedByString:@" "];
            NSString *what = [parts objectAtIndex:0];
            NSString *length = [parts objectAtIndex:2];
            
            if ([what hasPrefix:@"/dev/fd/"]) {
				_processedBytes -= [[_processedBytesMap objectForKey:what] integerValue];
			}
            [_processedBytesMap setObject:length forKey:what];
            
            _processedBytes += [length integerValue];
            
            self.progressHandler(_processedBytes, _totalInData); 
            
            break;
        }
            
        default:
            self.processStatus(keyword, value);
            break;
    }
}

- (void)getPassphraseAndForward {
    NSString *passphrase = nil;
    @try {
        passphrase = [self passphraseForKeyID:[self.needPassphraseInfo objectForKey:@"keyID"] 
                                    mainKeyID:[self.needPassphraseInfo objectForKey:@"mainKeyID"] 
                                       userID:[self.userIDHint objectForKey:@"userID"]];
        
    }
    @catch (NSException *exception) {
        [self cancel];
        @throw exception;
    }
    @finally {
        self.userIDHint = nil;
        self.needPassphraseInfo = nil;
    }
    
    [self replyToCommand:passphrase];
}

- (void)replyToCommand:(id)response {
    // Try to write to the command pipe.
    NSPipe *cmdPipe = nil;
    @try {
        cmdPipe = [self.task inheritedPipeWithName:@"stdin"];
    }
    @catch (NSException *exception) {
    }
    if(!cmdPipe)
        return;
    
    NSMutableData *responseData = [[NSMutableData alloc] init];
    [responseData appendData:[response isKindOfClass:[NSData class]] ? response : [[response description] dataUsingEncoding:NSUTF8StringEncoding]];
    [responseData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    GPGStream *responseStream = [GPGMemoryStream memoryStream];
    [responseStream writeData:responseData];
    [self writeData:responseStream pipe:[self.task inheritedPipeWithName:@"stdin"] close:NO];
}

- (NSString *)passphraseForKeyID:(NSString *)keyID mainKeyID:(NSString *)mainKeyID userID:(NSString *)userID {
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [GPGTaskHelper pinentryPath];
    task.standardInput = [[NSPipe pipe] noSIGPIPE];
    task.standardOutput = [[NSPipe pipe] noSIGPIPE];
    
    NSString *description = nil;
    if([keyID isEqualToString:mainKeyID])
        description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription"), userID, [keyID shortKeyID]];
    else
        description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription_Subkey"), 
					   userID, [keyID shortKeyID], [mainKeyID keyID]];
    
    description = [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *prompt = [localizedLibmacgpgString(@"PassphraseLabel") stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSData *command = [[NSString stringWithFormat:
                        @"OPTION grab\n"
                        "OPTION cache-id=%@\n"
                        "SETDESC %@\n"
                        "SETPROMPT %@\n"
                        "GETPIN\n"
                        "BYE\n",
                        keyID, description, prompt] dataUsingEncoding:NSUTF8StringEncoding];
    
    [[task.standardInput fileHandleForWriting] writeData:command];
    
    [task launch];
    
    NSData *output = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    [task waitUntilExit];
    
    [task release];
    
    if(!output)
        @throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
    
    NSString *outString = [output gpgString];
    
    // Versions prior to 0.8 of pinentry-mac do not seem
    // to support the OPTION cache-id yet, but still the
    // password is successfully retrieved.
    // To not abort on such an error, first the output string
    // is checked for a non empty D line and if not found,
    // any errors are processed.
    NSRange range = [outString rangeOfString:@"\nD "];
	if(range.location != NSNotFound) {
        range.location++;
        range.length--;
        range = [outString lineRangeForRange:range];
        range.location += 2;
        range.length -= 3;
        
        if(range.length > 0) {
            return [[outString substringWithRange:range] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    // Otherwise process the error.
    
	range = [outString rangeOfString:@"\nERR "];
	if (range.length > 0) {
		range.location++; 
		range.length--;
		range = [outString lineRangeForRange:range];
		range.location += 4;
		range.length -= 5;
		NSRange spaceRange = [outString rangeOfString:@" " options:NSLiteralSearch range:range];
		if (spaceRange.length > 0) {
			range.length = spaceRange.location - range.location;
		}
		if ([[outString substringWithRange:range] integerValue] == 0x5000063) {
			[self cancel];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
		}
		return nil;
	}
    return nil;
}

- (void)cancel {
    if(_cancelled)
        return;
    [self.task cancel];
    _cancelled = YES;
}

- (NSDictionary *)result {
    CFMutableDictionaryRef cfResult = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    if(self.status)
        CFDictionaryAddValue(cfResult, @"status", self.status);
    if(self.errors)
        CFDictionaryAddValue(cfResult, @"errors", self.errors);
    if(self.attributes)
        CFDictionaryAddValue(cfResult, @"attributes", self.attributes);
    if(self.output)
        CFDictionaryAddValue(cfResult, @"output", self.output);
    CFDictionaryAddValue(cfResult, @"exitcode", [NSNumber numberWithInt:self.exitStatus]);
    
    return (NSDictionary *)cfResult;
}

+ (NSDictionary *)statusCodes {
    static NSDictionary *GPG_STATUS_CODES = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GPG_STATUS_CODES = [[NSDictionary alloc] initWithObjectsAndKeys:
                            [NSNumber numberWithInteger:GPG_STATUS_ALREADY_SIGNED], @"ALREADY_SIGNED",
                            [NSNumber numberWithInteger:GPG_STATUS_ATTRIBUTE], @"ATTRIBUTE",
                            [NSNumber numberWithInteger:GPG_STATUS_BACKUP_KEY_CREATED], @"BACKUP_KEY_CREATED",
                            [NSNumber numberWithInteger:GPG_STATUS_BADARMOR], @"BADARMOR",
                            [NSNumber numberWithInteger:GPG_STATUS_BADMDC], @"BADMDC",
                            [NSNumber numberWithInteger:GPG_STATUS_BADSIG], @"BADSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_BAD_PASSPHRASE], @"BAD_PASSPHRASE",
                            [NSNumber numberWithInteger:GPG_STATUS_BEGIN_DECRYPTION], @"BEGIN_DECRYPTION",
                            [NSNumber numberWithInteger:GPG_STATUS_BEGIN_ENCRYPTION], @"BEGIN_ENCRYPTION",
                            [NSNumber numberWithInteger:GPG_STATUS_BEGIN_SIGNING], @"BEGIN_SIGNING",
                            [NSNumber numberWithInteger:GPG_STATUS_BEGIN_STREAM], @"BEGIN_STREAM",
                            [NSNumber numberWithInteger:GPG_STATUS_CARDCTRL], @"CARDCTRL",
                            [NSNumber numberWithInteger:GPG_STATUS_DECRYPTION_FAILED], @"DECRYPTION_FAILED",
                            [NSNumber numberWithInteger:GPG_STATUS_DECRYPTION_OKAY], @"DECRYPTION_OKAY",
                            [NSNumber numberWithInteger:GPG_STATUS_DELETE_PROBLEM], @"DELETE_PROBLEM",
                            [NSNumber numberWithInteger:GPG_STATUS_ENC_TO], @"ENC_TO",
                            [NSNumber numberWithInteger:GPG_STATUS_END_DECRYPTION], @"END_DECRYPTION",
                            [NSNumber numberWithInteger:GPG_STATUS_END_ENCRYPTION], @"END_ENCRYPTION",
                            [NSNumber numberWithInteger:GPG_STATUS_END_STREAM], @"END_STREAM",
                            [NSNumber numberWithInteger:GPG_STATUS_ERRMDC], @"ERRMDC",
                            [NSNumber numberWithInteger:GPG_STATUS_ERROR], @"ERROR",
                            [NSNumber numberWithInteger:GPG_STATUS_ERRSIG], @"ERRSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_EXPKEYSIG], @"EXPKEYSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_EXPSIG], @"EXPSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_FILE_DONE], @"FILE_DONE",
                            [NSNumber numberWithInteger:GPG_STATUS_GET_BOOL], @"GET_BOOL",
                            [NSNumber numberWithInteger:GPG_STATUS_GET_HIDDEN], @"GET_HIDDEN",
                            [NSNumber numberWithInteger:GPG_STATUS_GET_LINE], @"GET_LINE",
                            [NSNumber numberWithInteger:GPG_STATUS_GOODMDC], @"GOODMDC",
                            [NSNumber numberWithInteger:GPG_STATUS_GOODSIG], @"GOODSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_GOOD_PASSPHRASE], @"GOOD_PASSPHRASE",
                            [NSNumber numberWithInteger:GPG_STATUS_GOT_IT], @"GOT_IT",
                            [NSNumber numberWithInteger:GPG_STATUS_IMPORTED], @"IMPORTED",
                            [NSNumber numberWithInteger:GPG_STATUS_IMPORT_CHECK], @"IMPORT_CHECK",
                            [NSNumber numberWithInteger:GPG_STATUS_IMPORT_OK], @"IMPORT_OK",
                            [NSNumber numberWithInteger:GPG_STATUS_IMPORT_PROBLEM], @"IMPORT_PROBLEM",
                            [NSNumber numberWithInteger:GPG_STATUS_IMPORT_RES], @"IMPORT_RES",
                            [NSNumber numberWithInteger:GPG_STATUS_INV_RECP], @"INV_RECP",
                            [NSNumber numberWithInteger:GPG_STATUS_INV_SGNR], @"INV_SGNR",
                            [NSNumber numberWithInteger:GPG_STATUS_KEYEXPIRED], @"KEYEXPIRED",
                            [NSNumber numberWithInteger:GPG_STATUS_KEYREVOKED], @"KEYREVOKED",
                            [NSNumber numberWithInteger:GPG_STATUS_KEY_CREATED], @"KEY_CREATED",
                            [NSNumber numberWithInteger:GPG_STATUS_KEY_NOT_CREATED], @"KEY_NOT_CREATED",
                            [NSNumber numberWithInteger:GPG_STATUS_MISSING_PASSPHRASE], @"MISSING_PASSPHRASE",
                            [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE], @"NEED_PASSPHRASE",
                            [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE_PIN], @"NEED_PASSPHRASE_PIN",
                            [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE_SYM], @"NEED_PASSPHRASE_SYM",
                            [NSNumber numberWithInteger:GPG_STATUS_NEWSIG], @"NEWSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_NODATA], @"NODATA",
                            [NSNumber numberWithInteger:GPG_STATUS_NOTATION_DATA], @"NOTATION_DATA",
                            [NSNumber numberWithInteger:GPG_STATUS_NOTATION_NAME], @"NOTATION_NAME",
                            [NSNumber numberWithInteger:GPG_STATUS_NO_PUBKEY], @"NO_PUBKEY",
                            [NSNumber numberWithInteger:GPG_STATUS_NO_RECP], @"NO_RECP",
                            [NSNumber numberWithInteger:GPG_STATUS_NO_SECKEY], @"NO_SECKEY",
                            [NSNumber numberWithInteger:GPG_STATUS_NO_SGNR], @"NO_SGNR",
                            [NSNumber numberWithInteger:GPG_STATUS_PKA_TRUST_BAD], @"PKA_TRUST_BAD",
                            [NSNumber numberWithInteger:GPG_STATUS_PKA_TRUST_GOOD], @"PKA_TRUST_GOOD",
                            [NSNumber numberWithInteger:GPG_STATUS_PLAINTEXT], @"PLAINTEXT",
                            [NSNumber numberWithInteger:GPG_STATUS_PLAINTEXT_LENGTH], @"PLAINTEXT_LENGTH",
                            [NSNumber numberWithInteger:GPG_STATUS_POLICY_URL], @"POLICY_URL",
                            [NSNumber numberWithInteger:GPG_STATUS_PROGRESS], @"PROGRESS",
                            [NSNumber numberWithInteger:GPG_STATUS_REVKEYSIG], @"REVKEYSIG",
                            [NSNumber numberWithInteger:GPG_STATUS_RSA_OR_IDEA], @"RSA_OR_IDEA",
                            [NSNumber numberWithInteger:GPG_STATUS_SC_OP_FAILURE], @"SC_OP_FAILURE",
                            [NSNumber numberWithInteger:GPG_STATUS_SC_OP_SUCCESS], @"SC_OP_SUCCESS",
                            [NSNumber numberWithInteger:GPG_STATUS_SESSION_KEY], @"SESSION_KEY",
                            [NSNumber numberWithInteger:GPG_STATUS_SHM_GET], @"SHM_GET",
                            [NSNumber numberWithInteger:GPG_STATUS_SHM_GET_BOOL], @"SHM_GET_BOOL",
                            [NSNumber numberWithInteger:GPG_STATUS_SHM_GET_HIDDEN], @"SHM_GET_HIDDEN",
                            [NSNumber numberWithInteger:GPG_STATUS_SHM_INFO], @"SHM_INFO",
                            [NSNumber numberWithInteger:GPG_STATUS_SIGEXPIRED], @"SIGEXPIRED",
                            [NSNumber numberWithInteger:GPG_STATUS_SIG_CREATED], @"SIG_CREATED",
                            [NSNumber numberWithInteger:GPG_STATUS_SIG_ID], @"SIG_ID",
                            [NSNumber numberWithInteger:GPG_STATUS_SIG_SUBPACKET], @"SIG_SUBPACKET",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUNCATED], @"TRUNCATED",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUST_FULLY], @"TRUST_FULLY",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUST_MARGINAL], @"TRUST_MARGINAL",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUST_NEVER], @"TRUST_NEVER",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUST_ULTIMATE], @"TRUST_ULTIMATE",
                            [NSNumber numberWithInteger:GPG_STATUS_TRUST_UNDEFINED], @"TRUST_UNDEFINED",
                            [NSNumber numberWithInteger:GPG_STATUS_UNEXPECTED], @"UNEXPECTED",
                            [NSNumber numberWithInteger:GPG_STATUS_USERID_HINT], @"USERID_HINT",
                            [NSNumber numberWithInteger:GPG_STATUS_VALIDSIG], @"VALIDSIG",
                            nil];
    });
    return GPG_STATUS_CODES;
}

- (void)dealloc {
    [super dealloc];
    
    [_inData release];
    _inData = nil;
    [_arguments release];
    _arguments = nil;
    [_output release];
    _output = nil;
    [_status release];
    _status = nil;
    [_errors release];
    _errors = nil;
    [_attributes release];
    _attributes = nil;
    [_task release];
    _task = nil;
    [_processStatus release];
    _processStatus = nil;
    [_userIDHint release];
    _userIDHint = nil;
    [_needPassphraseInfo release];
    _needPassphraseInfo = nil;
    [_progressHandler release];
    _progressHandler = nil;
    [_processedBytesMap release];
    _processedBytesMap = nil;
}

@end

//
//  NSBundle+OBCodeSigningInfo.m
//
//  Created by Ole Begemann on 22.02.12.
//  Copyright (c) 2012 Ole Begemann. All rights reserved.
//

#import <Security/SecRequirement.h>
#import <objc/runtime.h>


@interface NSBundle (OBCodeSigningInfoPrivateMethods)
- (SecStaticCodeRef)ob_createStaticCode;
- (SecRequirementRef)ob_sandboxRequirement;
@end


@implementation NSBundle (OBCodeSigningInfo)

- (BOOL)ob_comesFromAppStore
{
    // Check existence of Mac App Store receipt
    NSURL *appStoreReceiptURL = [self appStoreReceiptURL];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    BOOL appStoreReceiptExists = [fileManager fileExistsAtPath:[appStoreReceiptURL path]];
    [fileManager release];
    return appStoreReceiptExists;
}


- (BOOL)ob_isSandboxed
{
    BOOL isSandboxed = NO;
    if ([self ob_codeSignState] == OBCodeSignStateSignatureValid) 
    {
        SecStaticCodeRef staticCode = [self ob_createStaticCode];
        SecRequirementRef sandboxRequirement = [self ob_sandboxRequirement];
        if (staticCode && sandboxRequirement) {
            OSStatus codeCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, sandboxRequirement, NULL);
            if (codeCheckResult == errSecSuccess) {
                isSandboxed = YES;
            }
            CFRelease(staticCode);
        }
    }
    return isSandboxed;
}


- (OBCodeSignState)ob_codeSignState
{
    // Return cached value if it exists
    static const void *kOBCodeSignStateKey;
    NSNumber *resultStateNumber = objc_getAssociatedObject(self, kOBCodeSignStateKey);
    if (resultStateNumber) {
        return [resultStateNumber integerValue];
    }
    
    // Determine code sign status
    OBCodeSignState resultState = OBCodeSignStateError;
    SecStaticCodeRef staticCode = [self ob_createStaticCode];
    if (staticCode) 
    {
        OSStatus signatureCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, NULL, NULL);
        switch (signatureCheckResult) {
            case errSecSuccess: resultState = OBCodeSignStateSignatureValid; break;
            case errSecCSUnsigned: resultState = OBCodeSignStateUnsigned; break;
            case errSecCSSignatureFailed:
            case errSecCSSignatureInvalid:
                resultState = OBCodeSignStateSignatureInvalid;
                break;
            case errSecCSSignatureNotVerifiable: resultState = OBCodeSignStateSignatureNotVerifiable; break;
            case errSecCSSignatureUnsupported: resultState = OBCodeSignStateSignatureUnsupported; break;
            default: resultState = OBCodeSignStateError; break;
        }
        CFRelease(staticCode);
    }
    else
    {
        resultState = OBCodeSignStateError;
    }
    
    // Cache the result
    resultStateNumber = [NSNumber numberWithInteger:resultState];
    objc_setAssociatedObject(self, kOBCodeSignStateKey, resultStateNumber, OBJC_ASSOCIATION_RETAIN);
    
    return resultState;
}


#pragma mark - Private helper methods

- (SecStaticCodeRef)ob_createStaticCode
{
    NSURL *bundleURL = [self bundleURL];
    SecStaticCodeRef staticCode = NULL;
    SecStaticCodeCreateWithPath((__bridge CFURLRef)bundleURL, kSecCSDefaultFlags, &staticCode);
    return staticCode;
}

- (SecRequirementRef)ob_sandboxRequirement
{
    static SecRequirementRef sandboxRequirement = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SecRequirementCreateWithString(CFSTR("entitlement[\"com.apple.security.app-sandbox\"] exists"), kSecCSDefaultFlags, &sandboxRequirement);
    });
    return sandboxRequirement;
}

@end
