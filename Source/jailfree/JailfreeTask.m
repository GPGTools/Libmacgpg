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
#import "GPGTaskHelper.h"

@implementation JailfreeTask

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
        NSDictionary *result = [task result];
        NSData *output = [[result objectForKey:@"output"] readAllData];
        
        NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:result];
        [response setValue:output forKey:@"output"];
        
        reply(response);
    }
    @catch (NSException *exception) {
        // Create error here.
        reply(nil);
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
