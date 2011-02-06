#import "GPGGlobals.h"


@interface GPGRemoteKey : NSObject {
	NSString *keyID;
	GPGPublicKeyAlgorithm algorithm;
	NSUInteger length;
	NSDate *creationDate;
	NSDate *expirationDate;
	BOOL expired;
	BOOL revoked;
	NSArray *userIDs;
}

@property (readonly) NSString *keyID;
@property (readonly) GPGPublicKeyAlgorithm algorithm;
@property (readonly) NSUInteger length;
@property (readonly) NSDate *creationDate;
@property (readonly) NSDate *expirationDate;
@property (readonly) BOOL expired;
@property (readonly) BOOL revoked;
@property (readonly) NSArray *userIDs;


+ (NSArray *)keysWithListing:(NSString *)listing;
+ (id)keyWithListing:(NSArray *)listing;
- (id)initWithListing:(NSArray *)listing;

@end
