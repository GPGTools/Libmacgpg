#import "GPGGlobals.h"


@interface GPGSignature : NSObject {
	GPGValidity trust;
	GPGErrorCode status;
	
	NSString *fingerprint;
	NSString *primaryFingerprint;
	NSString *userID;
	
	NSDate *creationDate;
	NSDate *expirationDate;
	
	int version;
	int publicKeyAlgorithm;
	int hashAlgorithm;
	NSString *signatureClass;
	
	BOOL hasFilled;
}
@property GPGErrorCode status;
@property GPGValidity trust;
@property BOOL hasFilled;
@property (retain) NSString *fingerprint;
@property (retain) NSString *primaryFingerprint;
@property (retain) NSString *userID;
@property (retain) NSDate *creationDate;
@property (retain) NSDate *expirationDate;
@property int version;
@property int publicKeyAlgorithm;
@property int hashAlgorithm;
@property (retain) NSString *signatureClass;


- (void)addInfoFromStatusCode:(NSInteger)status andPrompt:(NSString *)prompt;

@end
