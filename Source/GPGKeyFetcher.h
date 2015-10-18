
@interface GPGKeyFetcher : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSCache *cache;
}

- (void)fetchKeyForMailAddress:(NSString *)mailAddress block:(void (^)(NSData *data, NSString *verifiedMail, NSError *error))block;

@end
