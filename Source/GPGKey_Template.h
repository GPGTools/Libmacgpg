
#import "GPGGlobals.h"
#import "GPGSuper_Template.h"


@interface GPGKey_Template : GPGSuper_Template {
	NSString *keyID;
	NSString *shortKeyID;
	
	GPGPublicKeyAlgorithm algorithm;
	unsigned int length;
}

@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;
@property GPGPublicKeyAlgorithm algorithm;
@property unsigned int length;


@end
