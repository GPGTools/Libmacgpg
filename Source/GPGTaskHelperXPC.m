	#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080

/* GPGTaskHelperXPC.m created by Lukas Pitschl (@lukele) on Mon 22-Apr-2014 */

/*
 * Copyright (c) 2000-2014, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Team nor the names of Libmacgpg
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
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

#import "Libmacgpg.h"
#import "GPGTaskHelper.h"
#import "GPGTaskHelperXPC.h"

@interface GPGTaskHelperXPC ()

@property (nonatomic) NSXPCConnection *connection;
@property (nonatomic) dispatch_semaphore_t taskLock;
@property (nonatomic) BOOL wasShutdown;
@property (nonatomic, retain, readwrite) NSException *connectionError;

@end

@implementation GPGTaskHelperXPC

@synthesize connection=_connection, taskLock=_taskLock, progressHandler=_progressHandler, processStatus=_processStatus, wasShutdown=_wasShutdown, connectionError=_connectionError;

#pragma mark - XPC connection helpers

- (id)init {
	self = [super init];
	if(self) {
		_connection = [[NSXPCConnection alloc] initWithMachServiceName:JAILFREE_XPC_NAME options:0];
		_connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
		_connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
		_connection.exportedObject = self;
		
		// The invalidation handler is called when there's a problem establishing
		// the connection to the xpc service or it can't be found at all.
		__block typeof(self) weakSelf = self;
		_connection.invalidationHandler = ^{
			// Signal any outstanding tasks that they are done.
			// This handler is always called, when the connection is shutdown,
			// but more importantly also, when no connection could be established,
			// so catch that!
			if(weakSelf.wasShutdown)
				return;
			
			weakSelf.connectionError = [GPGException exceptionWithReason:@"[Libmacgpg] Failed to establish connection to org.gpgtools.Libmacgpg.xpc" errorCode:GPGErrorXPCConnectionError];
			
			[weakSelf completeTask];
		};
		
		_taskLock = dispatch_semaphore_create(0);
		
		// Setup the remote object with error handler.
		_connectionError = nil;
		
		// The error handler is invoked in the following cases:
		// - The xpc service crashes due to some error (for example overrelease.)
		// - If the xpc service is killed (process killed, also with -9)
		// - If the xpc service is unloaded with launchctl unload.
		// - If the xpc service is removed with launchctl remove.
		_jailfree = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
			// The connection has been invalidated by ourselves.
			// No need to log anything.
			if(weakSelf.wasShutdown)
				return;
			
			weakSelf.connectionError = [GPGException exceptionWithReason:@"[Libmacgpg] Failed to invoke XPC method" errorCode:GPGErrorXPCConnectionInterruptedError];
			
			[weakSelf completeTask];
		}];
	}
	return self;
}

- (BOOL)healthyXPCBinaryExists {
#ifdef DEBUGGING
	// Developers should know what they're doing, so this can always return YES.
	// Simply properly load the xpc if it doesn't work.
	return YES;
#endif
	
	BOOL healthy = NO;
	NSString *xpcBinaryName = @"org.gpgtools.Libmacgpg.xpc";
	NSString *xpcBinaryPath = [@"/Library/Application Support/GPGTools" stringByAppendingPathComponent:xpcBinaryName];
	if([[NSFileManager defaultManager] isExecutableFileAtPath:xpcBinaryPath])
		healthy = YES;
	
	return healthy;
}

- (void)prepareTask {
	// Reset connection error.
	self.connectionError = nil;
	
	// NSXPCConnection is not checking if the binary for the xpc service actually
	// exists and hence doesn't invoke an error handler if it doesn't.
	// So we do the check for it, and throw an error if necessary.
	if(![self healthyXPCBinaryExists]) {
		self.connectionError = [GPGException exceptionWithReason:@"[Libmacgpg] The xpc service binary is not available. Please re-install GPGTools from https://gpgtools.org" errorCode:GPGErrorXPCBinaryError];
		[self shutdownAndThrowError:self.connectionError];
	}
	// Resume will trigger the invalidationHandler if the connection can't
	// be established, for example, if the xpc service is not registered.
	[_connection resume];
}

- (void)waitForTaskToCompleteAndShutdown:(BOOL)shutdown throwExceptionIfNecessary:(BOOL)throwException {
	// No timeout necessary unless there's a bug in libxpc.
	dispatch_semaphore_wait(_taskLock, DISPATCH_TIME_FOREVER);
	dispatch_release(_taskLock);
	_taskLock = nil;
	
	if(shutdown) {
		if(self.connectionError && throwException)
			[self shutdownAndThrowError:self.connectionError];
		else
			[self shutdown];
	}
}

- (void)shutdownAndThrowError:(NSException *)error {
	NSException *errorCopy = nil;
	if(error == self.connectionError) {
		errorCopy = [_connectionError copy];
	}
	// Connection error is set to nil, so throw the errorCopy;
	[self shutdown];
	
	@throw errorCopy != nil ? [errorCopy autorelease] : error;
}

- (void)completeTask {
	if(_taskLock != NULL)
		dispatch_semaphore_signal(_taskLock);
}

#pragma mark XPC service methods

- (NSDictionary *)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes {
	[self prepareTask];
	
	NSException * __block taskError = nil;
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	[_jailfree launchGPGWithArguments:arguments data:data readAttributes:readAttributes reply:^(NSDictionary *info) {
		// Received an error? Convert it to an NSException and out of here.
		if([info objectForKey:@"exception"]) {
			NSDictionary *exceptionInfo = [info objectForKey:@"exception"];
			NSException *exception = nil;
			if(![exceptionInfo objectForKey:@"errorCode"]) {
				exception = [NSException exceptionWithName:[exceptionInfo objectForKey:@"name"] reason:[exceptionInfo objectForKey:@"reason"] userInfo:nil];
			}
			else {
				exception = [GPGException exceptionWithReason:[exceptionInfo objectForKey:@"reason"] errorCode:[[exceptionInfo objectForKey:@"errorCode"] unsignedIntValue]];
			}
			
			taskError = [exception retain];
			[self completeTask];
			
			return;
		}
		
        // If there's a problem with the XPC service, it's possible that one of the required
        // dictionary elements is not set. In that case, throw a general error.
        if(![info objectForKey:@"status"] || ![info objectForKey:@"errors"] || ![info objectForKey:@"exitcode"] || ![info objectForKey:@"output"]) {
            taskError = [[GPGException exceptionWithReason:@"Erron in XPC response" errorCode:GPGErrorXPCConnectionError] retain];
            [self completeTask];

            return;
        }
        [result setObject:[info objectForKey:@"status"] forKey:@"status"];
		if([info objectForKey:@"attributes"])
			[result setObject:[info objectForKey:@"attributes"] forKey:@"attributes"];
        [result setObject:[info objectForKey:@"errors"] forKey:@"errors"];
		[result setObject:[info objectForKey:@"exitcode"] forKey:@"exitStatus"];
		[result setObject:[info objectForKey:@"output"] forKey:@"output"];
		
        [self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(self.connectionError || taskError) {
		[result release];
		[self shutdownAndThrowError:self.connectionError ? self.connectionError : taskError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (NSString *)loadConfigFileAtPath:(NSString *)path {
	[self prepareTask];
	
	NSMutableString *result = [[NSMutableString alloc] init];
	
	[_jailfree loadConfigFileAtPath:path reply:^(NSString *content) {
		if(content)
			[result appendString:content];
		
		[self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(self.connectionError) {
		[result release];
		[self shutdownAndThrowError:self.connectionError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (NSDictionary *)loadUserDefaultsForName:(NSString *)domainName {
	[self prepareTask];
	
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[_jailfree loadUserDefaultsForName:domainName reply:^(NSDictionary *defaults) {
		if(defaults)
			[result addEntriesFromDictionary:defaults];
			
		[self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:NO throwExceptionIfNecessary:NO];
	
	if(self.connectionError) {
		[result release];
		[self shutdownAndThrowError:self.connectionError];
		return nil;
	}
	
	[self shutdown];
	
	return [result autorelease];
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName {
	[self prepareTask];

	__block BOOL success = NO;
	
	[_jailfree setUserDefaults:domain forName:domainName reply:^(BOOL result) {
		success = result;
		
		[self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
}


- (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	[self prepareTask];
	
	__block BOOL success = NO;
	
	[_jailfree launchGeneralTask:path withArguments:arguments wait:wait reply:^(BOOL result) {
		success = result;
		
		[self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
	
	return success;
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSString *)key {
	[self prepareTask];
	
	BOOL __block inCache = NO;
	
	[_jailfree isPassphraseForKeyInGPGAgentCache:key reply:^(BOOL result) {
		inCache = result;
		
		[self completeTask];
	}];
	
	[self waitForTaskToCompleteAndShutdown:YES throwExceptionIfNecessary:YES];
		
	return inCache;
}

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *))reply {
	if(!self.processStatus)
		return;
    
	NSData *response = self.processStatus(keyword, value);
    // Response can't be nil otherwise the reply won't be send as it turns out.
    response = response ? response : [[NSData alloc] init];
    reply(response);
}

- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total {
    if(self.progressHandler)
        self.progressHandler(processedBytes, total);
}

#pragma mark - XPC connection cleanup

- (void)shutdown {
	self.wasShutdown = YES;
	
	[_connectionError release];
	_connectionError = nil;
	
	_jailfree = nil;
	
	_connection.invalidationHandler = nil;
	_connection.interruptionHandler = nil;
	[_connection invalidate];
	_connection.exportedObject = nil;
	[_connection release];
	_connection = nil;
	
	if(_taskLock)
		dispatch_release(_taskLock);
	_taskLock = nil;
		
	Block_release(_processStatus);
	_processStatus = nil;
	Block_release(_progressHandler);
	_progressHandler = nil;
}

- (void)dealloc {
	if(!self.wasShutdown)
		[self shutdown];
	
	[super dealloc];
}

@end

#endif