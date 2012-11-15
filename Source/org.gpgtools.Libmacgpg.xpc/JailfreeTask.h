//
//  GPGXPCTask.h
//  Libmacgpg
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#import <Foundation/Foundation.h>

@class NSXPCConnection, NSXPCInterface, NSXPCListener, NSXPCListenerDelegate;

@protocol Jailfree <NSObject>

- (void)testConnection:(void (^)(BOOL))reply;
- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply;

- (void)startGPGWatcher;

@end

@protocol Jail <NSObject>

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *response))reply;
- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total;
- (void)postNotificationName:(NSString *)name object:(NSString *)object;

@end

@interface JailfreeTask :  NSObject <Jailfree>

- (void)testConnection:(void (^)(BOOL))reply;

#pragma mark - GPGTaskHelper RPC methods
- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply;

#pragma mark - GPGWatcher RPC methods
- (void)startGPGWatcher;

@property (weak) NSXPCConnection *xpcConnection;

@end
