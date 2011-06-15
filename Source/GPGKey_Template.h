#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGSuper_Template.h>


@interface GPGKey_Template : GPGSuper_Template {
	NSString *keyID;
	NSString *shortKeyID;
	
	GPGPublicKeyAlgorithm algorithm;
	unsigned int length;
	
	BOOL canEncrypt;
	BOOL canSign;
	BOOL canCertify;
	BOOL canAuthenticate;
}

@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;
@property GPGPublicKeyAlgorithm algorithm;
@property unsigned int length;
@property BOOL canEncrypt;
@property BOOL canSign;
@property BOOL canCertify;
@property BOOL canAuthenticate;


@end
