#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
//
//  GPGXPCTask.m
//  Libmacgpg
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#import "JailfreeTask.h"
#import "GPGMemoryStream.h"
#import "GPGWatcher.h"
#import "GPGException.h"
#import "GPGTaskHelper.h"

@interface JailfreeTask ()
- (BOOL)isCodeSignatureValidAtPath:(NSString *)path;
@end


@implementation JailfreeTask

@synthesize xpcConnection = _xpcConnection;

- (void)testConnection:(void (^)(BOOL))reply {
	reply(YES);
}

- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply {
    
	NSLog(@"Launching a new GPG task (only on >= 10.8)");
    GPGTaskHelper *task = [[GPGTaskHelper alloc] initWithArguments:arguments];
    
    // Setup the task.
	GPGMemoryStream *outputStream = [[GPGMemoryStream alloc] init];
    task.output = outputStream;
	
    NSMutableArray *inData = [[NSMutableArray alloc] init];
    [data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        GPGMemoryStream *stream = [[GPGMemoryStream alloc] initForReading:obj];
        [inData addObject:stream];
    }];
    task.inData = inData;
	id <Jail> remoteProxy = [_xpcConnection remoteObjectProxy];
    typeof(task) __weak weakTask = task;
    task.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value) {
        [remoteProxy processStatusWithKey:keyword value:value reply:^(NSData *response) {
			GPGTaskHelper *strongTask = weakTask;
            if(response)
                [strongTask respond:response];
        }];
    };
    task.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
        [remoteProxy progress:processedBytes total:totalBytes];
    };
    task.readAttributes = readAttributes;
    task.checkForSandbox = NO;
    
    @try {
		xpc_transaction_begin();
        // Start the task.
        [task run];
        // After completion, collect the result and send it back in the reply block.
        NSDictionary *result = [task copyResult];
        
		reply(result);
	}
    @catch (NSException *exception) {
        // Create error here.
        
		NSMutableDictionary *exceptionInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:exception.name, @"name",
											  exception.reason, @"reason", nil];
		if([exception isKindOfClass:[GPGException class]])
			[exceptionInfo setObject:[NSNumber numberWithUnsignedInt:((GPGException *)exception).errorCode] forKey:@"errorCode"];
		
		reply([NSDictionary dictionaryWithObjectsAndKeys:exceptionInfo, @"exception", nil]);
    }
    @finally {
		xpc_transaction_end();
    }
}

- (void)launchGeneralTask:(NSString *)path withArguments:(NSArray *)arguments reply:(void (^)(BOOL))reply {
	if ([self isCodeSignatureValidAtPath:path]) {
		[NSTask launchedTaskWithLaunchPath:path arguments:arguments];
		reply(YES);
	} else {
		NSLog(@"No valid signature at path: %@", path);
		reply(NO);
	}
}

- (void)startGPGWatcher {
    [GPGWatcher activateWithXPCConnection:self.xpcConnection];
}

- (void)loadConfigFileAtPath:(NSString *)path reply:(void (^)(NSString *))reply {
	NSLog(@"Loading the gnupg config file");
	
	NSArray *allowedConfigs = @[@"gpg.conf", @"gpg-agent.conf"];
	
	if(![allowedConfigs containsObject:[path lastPathComponent]])
		reply(nil);
	
	NSError * __autoreleasing error = nil;
 	NSString *configFile = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if(!configFile) {
		NSLog(@"Failed to load gpg.conf: %@", error);
		reply(nil);
	}
	
	reply(configFile);
}

- (void)loadUserDefaultsForName:(NSString *)domainName reply:(void (^)(NSDictionary *))reply {
	NSLog(@"Loading user defaults");
	
	NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:domainName];
	
	NSLog(@"User defaults for domain: %@\n\t:%@", domainName, defaults);
	
	reply(defaults);
}

- (void)setUserDefaults:(NSDictionary *)domain forName:(NSString *)domainName reply:(void (^)(BOOL))reply {
	NSLog(@"Save new user defaults for domain %@: %@", domainName, domain);
	
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:domain forName:domainName];
	
	reply(YES);
}







// Helper methods

- (BOOL)isCodeSignatureValidAtPath:(NSString *)path  {
    OSStatus result;
    SecRequirementRef requirement = nil;
    SecStaticCodeRef staticCode = nil;
        
    result = SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], 0, &staticCode);
    if (result) {
        goto finally;
    }
	
	result = SecRequirementCreateWithString(CFSTR("anchor apple generic and cert leaf = H\"233B4E43187B51BF7D6711053DD652DDF54B43BE\""), 0, &requirement);
	if (result) {
        goto finally;
    }

	result = SecStaticCodeCheckValidity(staticCode, 0, requirement);
    
finally:
    if (staticCode) CFRelease(staticCode);
    if (requirement) CFRelease(requirement);
    return result == 0;
}






@end
#endif