/* GPGTaskHelper created by Lukas Pitschl (@lukele) on Thu 02-Jun-2012 */

/*
 * Copyright (c) 2000-2014, GPGTools Project Team <gpgtools-org@lists.gpgtools.org>
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

#import "GPGOptions.h"
#import "GPGGlobals.h"
#import "GPGTaskHelper.h"
#import "GPGMemoryStream.h"
#import "LPXTTask.h"
#import "NSPipe+NoSigPipe.h"
#import "NSBundle+Sandbox.h"
#import "GPGException.h"
#import "JailfreeProtocol.h"
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
#import "GPGTaskHelperXPC.h"
#endif
#import "GPGTask.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

static const NSUInteger kDataBufferSize = 65536; 

typedef void (^basic_block_t)(void);

#pragma mark Helper methods
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
        @throw [exception retain];
    }
    @finally {
        [pool release];
    }
}

#pragma mark GPGTaskHelper

@interface GPGTaskHelper ()

@property (nonatomic, retain, readwrite) NSData *status;
@property (nonatomic, retain, readwrite) NSData *errors;
@property (nonatomic, retain, readwrite) NSData *attributes;
@property (nonatomic, retain, readonly) LPXTTask *task;
@property (nonatomic, retain) NSDictionary *userIDHint;
@property (nonatomic, retain) NSDictionary *needPassphraseInfo;

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close;

@end

@implementation GPGTaskHelper

@synthesize inData = _inData, arguments = _arguments, output = _output, processStatus = _processStatus, task = _task,
exitStatus = _exitStatus, status = _status, errors = _errors, attributes = _attributes, readAttributes = _readAttributes,
progressHandler = _progressHandler, userIDHint = _userIDHint, needPassphraseInfo = _needPassphraseInfo,
checkForSandbox = _checkForSandbox, timeout = _timeout, environmentVariables=_environmentVariables;

+ (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/bin", @"/usr/local/MacGPG2/bin", @"/usr/local/MacGPG1/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *newSearchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:newSearchPaths];
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
	if (!GPGPath) {
		onceToken = 0;
	}
    return GPGPath;
}

+ (NSString *)pinentryPath {
    static NSString *pinentryPath = nil;
    static dispatch_once_t pinentryToken;
    dispatch_once(&pinentryToken, ^{
		
		// New checking order:
		// 1. a defined "pinentry-program" in gpg-agent.conf
		// 2. pinentry-mac in a bundle named "org.gpgtools.Libmacgpg"
		// 3. a pinentry-mac executable in a set of dirs (e.g., /usr/local/bin)

		
		NSString *foundPath = nil;
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		static NSString * const kPinentry_program = @"pinentry-program";
        GPGOptions *options = [GPGOptions sharedOptions];
		
		// 1.
		// Read pinentry path from gpg-agent.conf
        NSString *inconfPath = [options valueForKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
        inconfPath = [inconfPath stringByStandardizingPath];
        
		if (inconfPath && [fileManager isExecutableFileAtPath:inconfPath]) {
            foundPath = inconfPath; // Use it, if valid.
		} else { // No valid pinentryPath.
			inconfPath = nil;
			
			// 2.
			// Search for pinentry in Libmacgpg.
			NSString *bundlePath = [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] pathForResource:@"pinentry-mac" ofType:@"" inDirectory:@"pinentry-mac.app/Contents/MacOS"];
			if (bundlePath && [fileManager isExecutableFileAtPath:bundlePath])
				foundPath = bundlePath;
		}
		
		
		
		if (!inconfPath) { // No (valid) pinentry ing pg-agent.conf
            if (!foundPath) {
				// 3.
                foundPath = [self findExecutableWithName:@"../libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac"];
            }
            if (foundPath) {
				// Set valid pinentry.
                [options setValue:foundPath forKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
                [options gpgAgentFlush];
            }
        }

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
	_task.environmentVariables = self.environmentVariables;
    
    if(!_task.launchPath || ![[NSFileManager defaultManager] isExecutableFileAtPath:_task.launchPath])
        @throw [GPGException exceptionWithReason:@"GPG not found!" errorCode:GPGErrorNotFound];
    
    GPGDebugLog(@"$> %@ %@", _task.launchPath, [_task.arguments componentsJoinedByString:@" "]);
	
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
    __block GPGTaskHelper *object = self;
    __block NSData *stderrData = nil;
    __block NSData *statusData = nil;
    __block NSData *attributeData = nil;
    __block LPXTTask *task = _task;
	
    __block NSObject *lock = [[[NSObject alloc] init] autorelease];
    
    _task.parentTask = ^{
		// On 10.6 it's not possible to create a concurrent private dispatch queue,
		// so we'll use the global queue with default priority. Seems to work without problems.
		dispatch_queue_t queue;
		if(NSAppKitVersionNumber >= NSAppKitVersionNumber10_7)
			queue = dispatch_queue_create("org.gpgtools.libmacgpg.gpgTaskHelper", DISPATCH_QUEUE_CONCURRENT);
        else {
			queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_retain(queue);
		}
			
		dispatch_group_t collectorGroup = dispatch_group_create();
        
        // The data is written to the pipe as soon as gpg issues the status
        // BEGIN_ENCRYPTION or BEGIN_SIGNING. See processStatus.
        // When we want to encrypt or sign, the data can't be written before the 
		// BEGIN_ENCRYPTION or BEGIN_SIGNING status was issued, BUT
        // in every other case, gpg stalls till it received the data to decrypt.
        // So in that case, the data actually has to be written as the very first thing.
        
        NSArray *options = [NSArray arrayWithObjects:@"--encrypt", @"--sign", @"--clearsign", @"--detach-sign", @"--symmetric", @"-e", @"-s", @"-b", @"-c", nil];
        
        if([object.arguments firstObjectCommonWithArray:options] == nil) {
            dispatch_group_async(collectorGroup, queue, ^{
                runBlockAndRecordExceptionSyncronized(^{
                    [object writeInputData];
                }, &lock, &blockException);
            });
        }
        
        dispatch_group_async(collectorGroup, queue, ^{
            runBlockAndRecordExceptionSyncronized(^{
                NSData *data;
                NSFileHandle *stdoutFH = [[task inheritedPipeWithName:@"stdout"] fileHandleForReading];
                while((data = [stdoutFH readDataOfLength:kDataBufferSize]) &&  [data length] > 0) {
                    withAutoreleasePool(^{
                        [object->_output writeData:data];
                    });
                }
            }, &lock, &blockException);
        });
        
        dispatch_group_async(collectorGroup, queue, ^{
            runBlockAndRecordExceptionSyncronized(^{
                NSFileHandle *stderrFH = [[task inheritedPipeWithName:@"stderr"] fileHandleForReading];
                stderrData = [[stderrFH readDataToEndOfFile] retain];
            }, &lock, &blockException);
        });
        
        if(object.readAttributes) {
            // Optionally get attribute data.
            dispatch_group_async(collectorGroup, queue, ^{
                runBlockAndRecordExceptionSyncronized(^{
                    NSFileHandle *attributeFH = [[task inheritedPipeWithName:@"attribute"] fileHandleForReading];
                    attributeData = [[attributeFH readDataToEndOfFile] retain];
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
    
    if (blockException && !_cancelled && !_pinentryCancelled) {
        @throw blockException;
	}
    
	self.status = statusData;
    [statusData release];
	self.errors = stderrData;
	[stderrData release];
    self.attributes = attributeData;
	[attributeData release];
    
    _exitStatus = _task.terminationStatus;
    
    if(_cancelled || (_pinentryCancelled && _exitStatus != 0))
        _exitStatus = GPGErrorCancelled;
    
	return _exitStatus;
}

- (BOOL)completed {
	return _task.completed;
}

- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total {
    if(self.progressHandler)
        self.progressHandler(processedBytes, total);
}

- (int)processIdentifier {
    return _task.processIdentifier;
}

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *))reply {
    NSData *response = self.processStatus(keyword, value);
    reply(response);
}

- (NSUInteger)_runInSandbox {
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
	// This code is only necessary for >= 10.8, don't even bother compiling it
	// on older platforms. Wouldn't anyway.
	// XPC name: org.gpgtools.Libmacgpg.jailfree.xpc_OpenStep
    
	__block GPGTaskHelper * weakSelf = self;
	
	GPGTaskHelperXPC *xpcTask = [[GPGTaskHelperXPC alloc] init];
	xpcTask.progressHandler = ^(NSUInteger processedBytes, NSUInteger total) {
		if(weakSelf.progressHandler)
			weakSelf.progressHandler(processedBytes, total);
	};
	xpcTask.processStatus = ^NSData *(NSString *keyword, NSString *value) {
		if(!self.processStatus)
			return nil;
		
		NSData *response = weakSelf.processStatus(keyword, value);
		return response;
	};

	NSMutableArray *inputData = [[NSMutableArray alloc] init];
	[_inData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[inputData addObject:[((GPGMemoryStream *)obj) readAllData]];
	}];
	[_inData release];
	_inData = nil;
	
	NSDictionary *result = nil;
	@try {
		result = [xpcTask launchGPGWithArguments:self.arguments data:inputData readAttributes:self.readAttributes];
	}
	@catch (NSException *exception) {
		[xpcTask release];
		[inputData release];
		@throw exception;
		
		return -1;
	}
	
	[inputData release];
	
	if([result objectForKey:@"output"])
		[_output writeData:[result objectForKey:@"output"]];
	[_output release];
	_output = nil;
	
	if([result objectForKey:@"status"])
		self.status = [result objectForKey:@"status"];
	if([result objectForKey:@"attributes"])
		self.attributes = [result objectForKey:@"attributes"];
	if([result objectForKey:@"errors"])
		self.errors = [result objectForKey:@"errors"];
	self.exitStatus = [[result objectForKey:@"exitStatus"] intValue];
	
	[xpcTask release];
	
	return [[result objectForKey:@"exitStatus"] intValue];
#else
	NSLog(@"This should never be called on OS X < 10.8? Please report to team@gpgtools.org if you're seeing this message.");
#endif
}

- (NSUInteger)run {
    if(self.checkForSandbox && [GPGTask sandboxed])
        return [self _runInSandbox];
    else
        return [self _run];
}

- (void)writeInputData {
    if(!_task || !self.inData) {
        return;
    }
    NSArray *pipeList = [self.task inheritedPipesWithName:@"ins"];
    __block GPGTaskHelper *bself = self;
	[pipeList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [bself writeData:[bself.inData objectAtIndex:idx] pipe:obj close:YES];
    }];
    
    self.inData = nil;
}

- (void)writeData:(GPGStream *)data pipe:(NSPipe *)pipe close:(BOOL)close {
    // If the task was already shutdown, it's still possible that
    // responds to status messages have to be processed in XPC mode.
    // In that case however the pipe no longer exists, so don't do anything.
    if(!pipe)
        return;
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
        
        if(close) {
            [ofh closeFile];
        }
    }
    @catch (NSException *exception) {
        // If the task is no longer running, there's no need to throw this exception
        // since it's expected.
        if(!self.completed)
            @throw exception;
        return;
    }
}

- (NSData *)parseStatusLines {
    NSMutableString *line = [NSMutableString string];
    NSPipe *statusPipe = [self.task inheritedPipeWithName:@"status"];
    NSFileHandle *statusFH = [statusPipe fileHandleForReading];
    
    NSData *currentData = nil;
    NSMutableData *statusData = [NSMutableData data]; 
    NSData *NL = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
    __block GPGTaskHelper *this = self;
	while((currentData = [statusFH availableData])&& [currentData length]) {
        [statusData appendData:currentData];
        [line appendString:[currentData gpgString]];
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
            [this processStatusWithKeyword:keyword value:value];
        }];
    }
    return statusData;
}

- (void)processStatusWithKeyword:(NSString *)keyword value:(NSString *)value {
    NSInteger code = [[[[self class] statusCodes] objectForKey:keyword] integerValue];
    if(!code)
        return;
    
	

    // Most keywords are handled by the processStatus callback,
    // but some like pinentry passphrase requests are handled
    // directly.
	
	NSData *response = self.processStatus(keyword, value);
    
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
				_pinentryCancelled = YES;
            break;
        }
        case GPG_STATUS_GET_LINE:
        case GPG_STATUS_GET_BOOL:
        case GPG_STATUS_GET_HIDDEN:
            if([value isEqualToString:@"passphrase.enter"])
                [self getPassphraseAndForward];
            else {
                if(response)
                    [self respond:response];
                else {
                    NSPipe *cmdPipe = [self.task inheritedPipeWithName:@"stdin"];
                    if(cmdPipe) {
                        [[cmdPipe fileHandleForWriting] closeFile];
                        [self.task removeInheritedPipeWithName:@"stdin"];
                    }
                }
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
            
            if(self.progressHandler) {
                self.progressHandler(_processedBytes, _totalInData);
            }
            
            break;
        }
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
    
    [self respond:passphrase];
}

- (void)respond:(id)response {
    // Try to write to the command pipe.
	// Ignore call, if response is empty data.
	if([response length] == 0)
		return;
	NSPipe *cmdPipe = nil;
    
    NSData *NL = [@"\n" dataUsingEncoding:NSASCIIStringEncoding];
    
    NSMutableData *responseData = [[NSMutableData alloc] init];
    [responseData appendData:[response isKindOfClass:[NSData class]] ? response : [[response description] dataUsingEncoding:NSUTF8StringEncoding]];
    if([responseData rangeOfData:NL options:NSDataSearchBackwards range:NSMakeRange(0, [responseData length])].location == NSNotFound)
        [responseData appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    GPGStream *responseStream = [GPGMemoryStream memoryStream];

    @try {
        cmdPipe = [self.task inheritedPipeWithName:@"stdin"];
    }
    @catch (NSException *exception) {
    }

    if(self.completed) {
        [responseData release];
        return;
    }

    if(!cmdPipe) {
        [responseData release];
        return;
    }

    [responseStream writeData:responseData];
    [self writeData:responseStream pipe:cmdPipe close:NO];
	[responseData release];
}

- (NSString *)passphraseForKeyID:(NSString *)keyID mainKeyID:(NSString *)mainKeyID userID:(NSString *)userID {
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [GPGTaskHelper pinentryPath];
    
	if(!task.launchPath)
		@throw [GPGException exceptionWithReason:@"Pinentry not found!" errorCode:GPGErrorNoPINEntry];
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
			@throw [GPGException exceptionWithReason:@"User cancelled pinentry request" errorCode:GPGErrorCancelled];
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

- (NSDictionary *)copyResult {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	if(self.status)
		[result setObject:self.status forKey:@"status"];
	if(self.errors)
		[result setObject:self.errors forKey:@"errors"];
	if(self.attributes)
		[result setObject:self.attributes forKey:@"attributes"];
	if(self.output)
		[result setObject:[self.output readAllData] forKey:@"output"];
	[result setObject:[NSNumber numberWithUnsignedInteger:self.exitStatus] forKey:@"exitcode"];
    
    return result;
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

+ (BOOL)isGPGAgentSocket:(NSString *)socketPath {
	socketPath = [socketPath stringByResolvingSymlinksInPath];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:socketPath error:nil];
	if ([[attributes fileType] isEqualToString:NSFileTypeSocket]) {
		return YES;
	}
	return NO;
}

+ (NSString *)gpgAgentSocket {
	NSString *socketPath = [[GPGOptions sharedOptions] valueForKey:@"GPG_AGENT_INFO" inDomain:GPGDomain_environment];
	NSRange range;
	if (socketPath && (range = [socketPath rangeOfString:@":"]).length > 0) {
		socketPath = [socketPath substringToIndex:range.location - 1];
		if ([self isGPGAgentSocket:socketPath]) {
			return socketPath;
		}
	}
	socketPath = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"S.gpg-agent"];
	if ([self isGPGAgentSocket:socketPath]) {
		return socketPath;
	}
	return nil;
}

+ (BOOL)isPassphraseInGPGAgentCache:(id)key {
	if(![key respondsToSelector:@selector(description)])
		return NO;
	
	NSString *socketPath = [GPGTaskHelper gpgAgentSocket];
	if (socketPath) {
		int sock;
		if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
			perror("socket");
			return NO;
		}
		
		unsigned long length = [socketPath lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 3;
		char addressInfo[length];
		addressInfo[0] = AF_UNIX;
		addressInfo[1] = 0;
		strncpy(addressInfo+2, [socketPath UTF8String], length - 2);
		
		if (connect(sock, (const struct sockaddr *)addressInfo, (socklen_t)length ) == -1) {
			perror("connect");
			goto closeSocket;
		}
		
		
		struct timeval socketTimeout;
		socketTimeout.tv_usec = 0;
		socketTimeout.tv_sec = 2;
		setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &socketTimeout, sizeof(socketTimeout));
		
		
		char buffer[100];
		if (recv(sock, buffer, 100, 0) > 2) {
			if (strncmp(buffer, "OK", 2)) {
				GPGDebugLog(@"No OK from gpg-agent.");
				goto closeSocket;
			}
			NSString *command = [NSString stringWithFormat:@"GET_PASSPHRASE --no-ask %@ . . .\n", key];
			send(sock, [command UTF8String], [command lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0);
			
			int pos = 0;
			while ((length = recv(sock, buffer+pos, 100-pos, 0)) > 0) {
				pos += length;
				if (strnstr(buffer, "OK", pos)) {
					return YES;
				} else if (strnstr(buffer, "ERR", pos)) {
					goto closeSocket;
				}
			}
		} else {
			return NO;
		}
	closeSocket:
		close(sock);
	}
	return NO;
}

- (void)dealloc {
    [_inData release];
    [_arguments release];
	[_output release];
    [_status release];
    [_errors release];
    [_attributes release];
    [_task release];
	_task = nil;
	[_processStatus release];
    [_userIDHint release];
    [_needPassphraseInfo release];
    [_progressHandler release];
    [_processedBytesMap release];
	[_environmentVariables release];
	
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    [_sandboxHelper release];
#endif
	
	[super dealloc];
}

+ (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	if ([GPGTask sandboxed]) {
		GPGTaskHelperXPC *xpcTask = [[GPGTaskHelperXPC alloc] init];
		
		BOOL succeeded = NO;
		@try {
			succeeded = [xpcTask launchGeneralTask:path withArguments:arguments wait:wait];
		}
		@catch (NSException *exception) {
			return NO;
		}
		@finally {
			[xpcTask release];
		}
		
		return succeeded;
	} else {
		NSTask *task = [NSTask launchedTaskWithLaunchPath:path arguments:arguments];
		if (wait) {
			[task waitUntilExit];
			return task.terminationStatus == 0;
		}
	}
	return YES;
}


@end
