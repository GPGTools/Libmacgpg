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
/*#import "NSDictionary+Subscripting.h"*/

@implementation JailfreeTask

- (void)testConnection:(void (^)(BOOL))reply {
	reply(YES);
}

- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply {
    
    GPGTaskHelper *task = [[GPGTaskHelper alloc] initWithArguments:arguments];
    
    // Setup the task.
    task.output = [GPGMemoryStream memoryStream];
    NSMutableArray *inData = [NSMutableArray array];
    [data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        GPGMemoryStream *stream = [GPGMemoryStream memoryStream];
        [stream writeData:obj];
        [inData addObject:stream];
    }];
    task.inData = inData;
    __block NSXPCConnection *connection = self.xpcConnection;
    __block typeof(task) btask = task;
    task.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value) {
        [[connection remoteObjectProxy] processStatusWithKey:keyword value:value reply:^(NSData *response) {
            if(response)
                [btask respond:response];
        }];
    };
    task.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
        [[connection remoteObjectProxy] progress:processedBytes total:totalBytes];
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
		
		//[result release];
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
        [task release];
    }
}

- (void)startGPGWatcher {
    [GPGWatcher activateWithXPCConnection:self.xpcConnection];
}

@end
