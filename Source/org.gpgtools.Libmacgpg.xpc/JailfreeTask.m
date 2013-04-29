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

- (void)startGPGWatcher {
    [GPGWatcher activateWithXPCConnection:self.xpcConnection];
}

@end
#endif