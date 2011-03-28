#import "GPGKey_Template.h"


@implementation GPGKey_Template

@synthesize keyID;
@synthesize shortKeyID;
@synthesize algorithm;
@synthesize length;
@synthesize canEncrypt;
@synthesize canSign;
@synthesize canCertify;
@synthesize canAuthenticate;


- (void)updateWithLine:(NSArray *)line {
	[super updateWithLine:line];
	
	length = [[line objectAtIndex:2] intValue];
	algorithm = [[line objectAtIndex:3] intValue];
	self.keyID = [line objectAtIndex:4];
	self.shortKeyID = getShortKeyID(keyID);
	
	
	const char *capabilities = [[line objectAtIndex:11] cStringUsingEncoding:NSASCIIStringEncoding];
	BOOL canSignVal = 0, canEncryptVal = 0, canCertifyVal = 0, canAuthenticateVal = 0, disabledVal = 0;
	
	for (; *capabilities; capabilities++) {
		switch (*capabilities) {
			case 'd':
			case 'D':
				disabledVal = 1;
				break;
			case 'e':
			case 'E':
				canEncryptVal = 1;
				break;
			case 's':
			case 'S':
				canSignVal = 1;
				break;
			case 'c':
			case 'C':
				canCertifyVal = 1;
				break;
			case 'a':
			case 'A':
				canAuthenticateVal = 1;
				break;
		}
	}
	
	
	self.canEncrypt = canEncryptVal;
	self.canSign = canSignVal;
	self.canCertify = canCertifyVal;
	self.canAuthenticate = canAuthenticateVal;
	self.disabled = disabledVal;
	
}




- (void)dealloc {
	self.keyID = nil;
	self.shortKeyID = nil;
	[super dealloc];
}

@end
