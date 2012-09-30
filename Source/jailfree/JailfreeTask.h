//
//  GPGXPCTask.h
//  Libmacgpg
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#import <Foundation/Foundation.h>

@protocol Jailfree <NSObject>

- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply;

//- (void)getOptionWithKey:(id)key;
//- (void)setOptionForKey:(id)key value:(id)value;

@end

@protocol Jail <NSObject>

- (void)processStatusWithKey:(NSString *)keyword value:(NSString *)value reply:(void (^)(NSData *response))reply;
- (void)progress:(NSUInteger)processedBytes total:(NSUInteger)total;

@end

@interface JailfreeTask :  NSObject <Jailfree>

- (void)launchGPGWithArguments:(NSArray *)arguments data:(NSArray *)data readAttributes:(BOOL)readAttributes reply:(void (^)(NSDictionary *))reply;

@property (weak) NSXPCConnection *xpcConnection;

@end
