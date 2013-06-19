#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080

/* GPGTaskHelperXPC.m created by Lukas Pitschl (@lukele) on Mon 22-Apr-2013 */

/*
 * Copyright (c) 2000-2013, GPGTools Team <team@gpgtools.org>
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
@property (nonatomic) NSUInteger timeout;
@property (nonatomic) dispatch_semaphore_t taskLock;
@property (nonatomic) dispatch_semaphore_t testLock;
@property (nonatomic) BOOL wasShutdown;

@end

@implementation GPGTaskHelperXPC

@synthesize connection=_connection, timeout=_timeout, taskLock=_taskLock, testLock=_testLock, progressHandler=_progressHandler, processStatus=_processStatus, wasShutdown=_wasShutdown;

- (id)initWithTimeout:(NSUInteger)aTimeout {
	self = [super init];
	if(self) {
		_timeout = aTimeout;
		_connection = [[NSXPCConnection alloc] initWithMachServiceName:JAILFREE_XPC_NAME options:0];
		_connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
		_connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
		_connection.exportedObject = self;
		
		[_connection resume];
		
		_taskLock = dispatch_semaphore_create(0);
		_testLock = dispatch_semaphore_create(0);
	}
	return self;
}

- (id)init {
	return [self initWithTimeout:NSEC_PER_SEC * 2];
}

- (BOOL)test {
	// TODO: This method will be removed soon and all the code calling it.
	return YES;
}

- (NSDictionary *)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
	
	NSException * __block connectionError = nil;
	NSException * __block taskError = nil;
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method - reason: %@", [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] launchGPGWithArguments:arguments data:data readAttributes:readAttributes reply:^(NSDictionary *info) {
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
			NSLog(@"[Libmacgpg] Failed to execute GPG task - %@", taskError);
			if(weakSelf && weakSelf->_taskLock != NULL)
				dispatch_semaphore_signal(weakSelf->_taskLock);

			return;
		}
		
		[result setObject:[info objectForKey:@"status"] forKey:@"status"];
		if([info objectForKey:@"attributes"])
			[result setObject:[info objectForKey:@"attributes"] forKey:@"attributes"];
		[result setObject:[info objectForKey:@"errors"] forKey:@"errors"];
		[result setObject:[info objectForKey:@"exitcode"] forKey:@"exitStatus"];
		[result setObject:[info objectForKey:@"output"] forKey:@"output"];
		
        if(weakSelf && weakSelf->_taskLock != NULL)
            dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
	
	if(connectionError) {
		[result release];
		@throw connectionError;
	}
		
	
	if(taskError) {
		[result release];
		@throw taskError;
	}
	
	return [result autorelease];
}

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *))reply {
	if(!self.processStatus)
		return;
    
	NSData *response = self.processStatus(keyword, value);
    reply(response);
}

- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total {
    if(self.progressHandler)
        self.progressHandler(processedBytes, total);
}

- (NSString *)loadConfigFileAtPath:(NSString *)path {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
	
	NSException * __block connectionError;
	
	NSMutableString *result = [[NSMutableString alloc] init];
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] loadConfigFileAtPath:path reply:^(NSString *content) {
		if(content)
			[result appendString:content];
		
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
	
	return [result autorelease];
}

- (NSDictionary *)loadUserDefaultsForName:(NSString *)domainName {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
	
	NSException * __block connectionError;
	
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] loadUserDefaultsForName:domainName reply:^(NSDictionary *defaults) {
		if(defaults)
			[result addEntriesFromDictionary:defaults];
		
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
	
	return [result autorelease];
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
		
	NSException * __block connectionError;
	__block BOOL success = NO;
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] setUserDefaults:domain forName:domainName reply:^(BOOL result) {
		success = result;
		
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
}


- (BOOL)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments wait:(BOOL)wait {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
	NSException * __block connectionError;
	
	__block BOOL success = NO;
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] launchGeneralTask:path withArguments:arguments wait:wait reply:^(BOOL result) {
		success = result;
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	 
	dispatch_semaphore_wait(_taskLock, timeout);
	
	return success;
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSString *)key {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	GPGTaskHelperXPC * __block weakSelf = self;
	NSException * __block connectionError = nil;
	BOOL __block inCache = NO;
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		// The connection has been invalidated by ourselves.
        // No need to log anything.
        if(error.code == NSXPCConnectionInvalid)
            return;
        
        NSString *explanation = [NSString stringWithFormat:@"[Libmacgpg] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [[NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil] retain];
		
		NSLog(@"%@", explanation);
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}] isPassphraseForKeyInGPGAgentCache:key reply:^(BOOL result) {
		inCache = result;
		
		if(weakSelf && weakSelf->_taskLock != NULL)
			dispatch_semaphore_signal(weakSelf->_taskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
	
	if(connectionError) {
		[connectionError release];
		return NO;
	}
	
	return inCache;
}


- (void)shutdown {
	[_connection invalidate];
	[_connection release];
	_connection = nil;
	
	if(_taskLock)
		dispatch_release(_taskLock);
	_taskLock = nil;
	if(_testLock)
		dispatch_release(_testLock);
	_testLock = nil;
	
	Block_release(_processStatus);
	_processStatus = nil;
	Block_release(_progressHandler);
	_progressHandler = nil;
	
	self.wasShutdown = YES;
}

- (void)dealloc {
	if(!self.wasShutdown)
		[self shutdown];
	
	[super dealloc];
}

@end

#endif