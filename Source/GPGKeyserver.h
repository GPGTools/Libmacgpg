//
//  GPGKeyserver.h
//  Libmacgpg
//
//  Created by Mento on 09.07.13.
//
//

#import <Foundation/Foundation.h>

@class GPGKeyserver;

@protocol GPGKeyserverDelegate <NSObject>
@required
- (void)keyserverDidFinishLoading:(GPGKeyserver *)keyserver;
- (void)keyserver:(GPGKeyserver *)keyserver didFailWithException:(NSException *)exception;
@end


@interface GPGKeyserver : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSString *keyserver;
	id <GPGKeyserverDelegate> delegate;
	NSDictionary *userInfo;
	BOOL isRunning;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
	BOOL _cancelled;
}

@property (assign, nonatomic) id <GPGKeyserverDelegate> delegate;
@property (retain, nonatomic) NSString *keyserver;
@property (retain, nonatomic, readonly) NSData *receivedData;
@property (retain, nonatomic) NSDictionary *userInfo;
@property (readonly, nonatomic) BOOL isRunning;


- (void)getKey:(NSString *)keyID;
- (void)searchKey:(NSString *)pattern;

- (void)cancel;

+ (id)keyserverWithDelegate:(id <GPGKeyserverDelegate>)delegate;
- (id)initWithDelegate:(id <GPGKeyserverDelegate>)delegate;


@end

