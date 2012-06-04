/* main.m created by Lukas Pitschl (@lukele) on Thu 02-Jun-2012 */

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

/**
 The GPGTaskHelper XPC service allows clients to safely communicate with the GPG binary.
 
 At the moment the service understand two actions:
 - new -> Setup and spawn a new GPG 2 process.
 - reply-cmd -> Respond to the GPG 2 process on GET_* statuses.
 
 'new' message params:
 - arguments (array): all command line arguments to pass to the gpg binary.
 - data (array of NSData's): data to feed the GPG 2 process with (optional)
 - readAttributes (bool): in the special case --attribute-fd messages should be read and processed.
 
 */

#import <Foundation/Foundation.h>
#import <xpc/xpc.h>
#import <XPCKit/XPCKit.h>
#import "GPGMemoryStream.h"

#import "GPGTaskHelper.h"

int main(int argc, const char *argv[])
{
    [XPCService runServiceWithConnectionHandler:^(XPCConnection *connection){
        GPGTaskHelper *helper = [[GPGTaskHelper alloc] initWithArguments:nil];
        
        [connection setEventHandler:^(XPCMessage *message, XPCConnection *connection){
            // action == new messages invoke a gpg2 process.
            // Further messages coming in with are used to communicate with
            // gpg2.
            if([[message objectForKey:@"action"] isEqualToString:@"new"]) {
                // If no specific action is specified, a new 
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    xpc_transaction_begin();
                    
                    XPCMessage *reply = [XPCMessage messageReplyForMessage:message];
                    
                    helper.arguments = [message objectForKey:@"arguments"];
                    helper.output = [GPGMemoryStream memoryStream];
                    // Incoming data has to be converted back to memory streams.
                    NSMutableArray *inData = [NSMutableArray array];
                    [[message objectForKey:@"data"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        GPGMemoryStream *stream = [GPGMemoryStream memoryStream];
                        [stream writeData:obj];
                        [inData addObject:stream];
                    }];
                    helper.inData = inData;
                    __block typeof(connection) bConnection = connection;
                    __block typeof(helper) bHelper = helper;
                    helper.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value){
                        [bConnection sendMessage:[XPCMessage messageWithObjectsAndKeys:@"status", @"action", keyword, @"keyword", value, @"value", nil] withReply:^(XPCMessage *inReply) {
                            if([inReply objectForKey:@"response"])
                                [bHelper replyToCommand:[inReply objectForKey:@"response"]];
                        }];
                        return nil;
                    };
                    helper.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
                        [bConnection sendMessage:[XPCMessage messageWithObjectsAndKeys:@"progress", @"action", [NSNumber numberWithUnsignedInt:processedBytes], @"processedBytes", [NSNumber numberWithUnsignedInt:totalBytes], @"totalBytes", nil]];
                    };
                    helper.readAttributes = [[message objectForKey:@"readAttributes"] boolValue];
                    
                    @try {
                        [helper run];
                        
                        NSDictionary *result = [helper result];
                        [result enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                            if([key isEqualToString:@"output"]) {
                                NSData *data = [obj readAllData];
                                // XPCMessage doesn't want empty data.
                                if([data length])
                                    [reply setObject:data forKey:key];
                            }
                            else
                                [reply setObject:obj forKey:key];
                        }];
                        [connection sendMessage:reply];
                    }
                    @catch (NSException *exception) {
                        [reply setObject:exception forKey:@"exception"];
                        [connection sendMessage:reply];
                    }
                    @finally {
                        [helper release];
                    }
                    
                    xpc_transaction_end();
                });
            }
            else {
                NSLog(@"I'm sorry, I don't understand this command...");
            }
        }];
	}];
    
	return 0;
}
