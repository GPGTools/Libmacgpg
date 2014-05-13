//
//  GPGKeyserver.h
//  Libmacgpg
//
//  Created by Mento on 09.07.13.
//
//

@class GPGKeyserver;

typedef void (^gpg_ks_finishedHandler)(GPGKeyserver *server);

@interface GPGKeyserver : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSString *keyserver;
	NSDictionary *userInfo;
	BOOL isRunning;
	SEL lastOperation;
	NSException *exception;
	gpg_ks_finishedHandler finishedHandler;
	NSUInteger timeout;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
	BOOL _cancelled;
}

@property (strong, nonatomic) NSString *keyserver;
@property (readonly, strong, nonatomic) NSData *receivedData;
@property (strong, nonatomic) NSDictionary *userInfo;
@property (readonly, nonatomic) BOOL isRunning;
@property (readonly, nonatomic) SEL lastOperation;
@property (readonly, strong, nonatomic) NSException *exception;
@property (nonatomic) NSUInteger timeout;

@property (nonatomic, copy) gpg_ks_finishedHandler finishedHandler;


- (void)getKey:(NSString *)keyID;
- (void)searchKey:(NSString *)pattern;
- (void)uploadKeys:(NSString *)armored;

- (void)cancel;

- (id)initWithFinishedHandler:(gpg_ks_finishedHandler)finishedHandler;


@end

