#import <Libmacgpg/GPGGlobals.h>


@interface GPGSuper_Template : NSObject {
	GPGValidity validity;
	BOOL expired;
	BOOL disabled;
	BOOL invalid;
	BOOL revoked;	
	
	NSDate *creationDate;
	NSDate *expirationDate;
}
@property GPGValidity validity;
@property BOOL expired;
@property BOOL disabled;
@property BOOL invalid;
@property BOOL revoked;
@property (readonly) NSInteger status;
@property (retain) NSDate *creationDate;
@property (retain) NSDate *expirationDate;


+ (GPGValidity)validityFromLetter:(NSString *)letter;
- (void)updateWithLine:(NSArray *)line;

@end
