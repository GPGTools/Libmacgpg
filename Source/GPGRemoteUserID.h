#import <Cocoa/Cocoa.h>


@interface GPGRemoteUserID : NSObject {
	NSString *userID;
	NSString *name;
	NSString *email;
	NSString *comment;
	NSDate *creationDate;
	NSDate *expirationDate;
}

@property (readonly) NSString *userID;
@property (readonly) NSString *name;
@property (readonly) NSString *email;
@property (readonly) NSString *comment;
@property (readonly) NSDate *creationDate;
@property (readonly) NSDate *expirationDate;


+ (id)userIDWithListing:(NSString *)listing;
- (id)initWithListing:(NSString *)listing;

@end
