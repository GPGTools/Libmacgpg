
@interface GPGKeyFetcher : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSCache *cache;
	NSURLSession *session;
}

- (void)fetchKeyForMailAddress:(NSString *)mailAddress block:(void (^)(NSData *data, NSString *verifiedMail, NSError *error))block;

@end
