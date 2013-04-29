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
 *     * Neither the name of GPGTools Team nor the names of GPGMail
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

@end

@implementation GPGTaskHelperXPC

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

- (BOOL)test {
	__block NSException *connectionError;
	dispatch_time_t testTimeout = dispatch_time(DISPATCH_TIME_NOW, GPGTASKHELPER_DISPATCH_TIMEOUT_ALMOST_INSTANTLY);
	
	__block BOOL success = NO;
	
	dispatch_semaphore_t __weak weakTestLock = _testLock;
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		NSString *description = [error description];
		NSString *explanation = [[NSString alloc] initWithFormat:@"[GPGMail] XPC test connection failed - reason: %@", description];
		
		connectionError = [NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil];
		
		NSLog(@"%@", explanation);
		
		dispatch_semaphore_signal(weakTestLock);
	}] testConnection:^(BOOL result) {
		success = YES;
		dispatch_semaphore_signal(weakTestLock);
	}];
	
	dispatch_semaphore_wait(_testLock, testTimeout);
	
	return success;
}

- (NSDictionary *)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	dispatch_semaphore_t __weak weakTaskLock = _taskLock;
	
	NSException * __block connectionError;
	NSException * __block taskError;
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		NSString *explanation = [NSString stringWithFormat:@"[GPGMail] Failed to invoke XPC method - reason: %@", [error description]];
		
		connectionError = [NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil];
		
		NSLog(@"%@", explanation);
		dispatch_semaphore_signal(weakTaskLock);
	}] launchGPGWithArguments:arguments data:data readAttributes:readAttributes reply:^(NSDictionary *info) {
		if([result objectForKey:@"exception"]) {
			NSDictionary *exceptionInfo = result[@"exception"];
			NSException *exception = nil;
			if(!exceptionInfo[@"errorCode"]) {
				exception = [NSException exceptionWithName:exceptionInfo[@"name"] reason:exceptionInfo[@"reason"] userInfo:nil];
			}
			else {
				exception = [GPGException exceptionWithReason:exceptionInfo[@"reason"] errorCode:[exceptionInfo[@"errorCode"] unsignedIntValue]];
			}
			
			taskError = exception;
			NSLog(@"[GPGMail] Failed to execute GPG task - %@", taskError);
			dispatch_semaphore_signal(weakTaskLock);

			return;
		}
		
		result[@"status"] = info[@"status"];
		if(info[@"attributes"])
			result[@"attributes"] = info[@"attributes"];
		result[@"errors"] = info[@"errors"];
		result[@"exitStatus"] = info[@"exitcode"];
		result[@"output"] = info[@"output"];
		
		dispatch_semaphore_signal(weakTaskLock);
	}];
	
	dispatch_semaphore_wait(_taskLock, timeout);
	
	if(connectionError)
		@throw connectionError;
	
	if(taskError)
		@throw taskError;
	
	return result;
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
	dispatch_semaphore_t __weak weakTaskLock = _taskLock;
	
	NSException * __block connectionError;
	
	NSMutableString *result = [[NSMutableString alloc] init];
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		NSString *explanation = [NSString stringWithFormat:@"[GPGMail] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil];
		
		NSLog(@"%@", explanation);
		dispatch_semaphore_signal(weakTaskLock);
	}] loadConfigFileAtPath:path reply:^(NSString *content) {
		if(content)
			[result appendString:content];
		
		dispatch_semaphore_signal(weakTaskLock);
	}];
	
	dispatch_semaphore_wait(weakTaskLock, timeout);
	
	return result;
}

- (NSDictionary *)loadUserDefaultsForName:(NSString *)domainName {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	dispatch_semaphore_t __weak weakTaskLock = _taskLock;
	
	NSException * __block connectionError;
	
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		NSString *explanation = [NSString stringWithFormat:@"[GPGMail] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil];
		
		NSLog(@"%@", explanation);
		dispatch_semaphore_signal(weakTaskLock);
	}] loadUserDefaultsForName:domainName reply:^(NSDictionary *defaults) {
		if(defaults)
			[result addEntriesFromDictionary:defaults];
		
		dispatch_semaphore_signal(weakTaskLock);
	}];
	
	dispatch_semaphore_wait(weakTaskLock, timeout);
	
	return result;
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName {
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, _timeout);
	#if __has_feature(objc_arc)
	NSLog(@"Heck Yes, ARC is on!");
	#endif
	#if OS_OBJECT_USE_OBJC
	NSLog(@"__weak should be just fine.");
	#else
	NSLog(@"Naah __weak ain't available");
	#endif
	dispatch_semaphore_t __weak weakTaskLock = _taskLock;
	
	NSException * __block connectionError;
	__block BOOL success = NO;
	
	[[_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		NSString *explanation = [NSString stringWithFormat:@"[GPGMail] Failed to invoke XPC method %@ - reason: %@", NSStringFromSelector(_cmd), [error description]];
		
		connectionError = [NSException exceptionWithName:@"XPCConnectionError" reason:explanation userInfo:nil];
		
		NSLog(@"%@", explanation);
		dispatch_semaphore_signal(weakTaskLock);
	}] setUserDefaults:domain forName:domainName reply:^(BOOL result) {
		success = result;
				
		dispatch_semaphore_signal(weakTaskLock);
	}];
	
	dispatch_semaphore_wait(weakTaskLock, timeout);
}


- (void)shutdown {
	[_connection invalidate];
	_connection.remoteObjectInterface = nil;
	_connection.exportedObject = nil;
	_connection.exportedInterface = nil;
	_connection = nil;
	
	_taskLock = nil;
	_testLock = nil;
}

@end

#endif