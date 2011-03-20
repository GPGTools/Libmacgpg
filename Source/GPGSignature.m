#import "GPGSignature.h"


@interface GPGSignature (Private)

- (void)getKeyIDAndUserIDFromPrompt:(NSString *)prompt;

@end



@implementation GPGSignature
@synthesize status;
@synthesize fingerprint;
@synthesize primaryFingerprint;
@synthesize hasFilled;
@synthesize trust;
@synthesize userID;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize version;
@synthesize publicKeyAlgorithm;
@synthesize hashAlgorithm;
@synthesize signatureClass;


- (void)addInfoFromStatusCode:(NSInteger)statusCode andPrompt:(NSString *)prompt  {
	if (statusCode == GPG_STATUS_NEWSIG) {
		return;
	}	
	NSArray *components = [prompt componentsSeparatedByString:@" "];
	
	switch (statusCode) {
		case GPG_STATUS_NEWSIG:
			break;
		case GPG_STATUS_GOODSIG:
			self.status = GPGErrorNoError;
			[self getKeyIDAndUserIDFromPrompt:prompt];
			break;
		case GPG_STATUS_EXPSIG:
			self.status = GPGErrorSignatureExpired;
			[self getKeyIDAndUserIDFromPrompt:prompt];
			break;
		case GPG_STATUS_EXPKEYSIG:
			self.status = GPGErrorKeyExpired;
			[self getKeyIDAndUserIDFromPrompt:prompt];
			break;
		case GPG_STATUS_BADSIG:
			self.status = GPGErrorBadSignature;
			[self getKeyIDAndUserIDFromPrompt:prompt];
			break;
		case GPG_STATUS_REVKEYSIG:
			self.status = GPGErrorCertificateRevoked;
			[self getKeyIDAndUserIDFromPrompt:prompt];
			break;
		case GPG_STATUS_ERRSIG: {
			self.fingerprint = [components objectAtIndex:0];
			self.publicKeyAlgorithm = [[components objectAtIndex:1] intValue];
			self.hashAlgorithm = [[components objectAtIndex:2] intValue];
			self.signatureClass = [components objectAtIndex:3];
			self.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:4]];
			int rc = [[components objectAtIndex:5] intValue];
			if (rc == 4) {
				self.status = GPGErrorUnknownAlgorithm;
			} else if (rc == 9) {
				self.status = GPGErrorNoPublicKey;
			} else {
				self.status = GPGErrorGeneralError;
			}
			
			break; }

	
		
		case GPG_STATUS_VALIDSIG:
			self.fingerprint = [components objectAtIndex:0];
			self.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:2]];
			self.expirationDate = [NSDate dateWithGPGString:[components objectAtIndex:3]];
			self.version = [[components objectAtIndex:4] intValue];
			self.publicKeyAlgorithm = [[components objectAtIndex:6] intValue];
			self.hashAlgorithm = [[components objectAtIndex:7] intValue];
			self.signatureClass = [components objectAtIndex:8];
			if ([components count] >= 10) {
				self.primaryFingerprint = [components objectAtIndex:9];
			}
			break;
			
			
		case GPG_STATUS_TRUST_UNDEFINED:
			trust = GPGValidityUndefined;
			break;
		case GPG_STATUS_TRUST_NEVER:
			trust = GPGValidityNever;
			break;
		case GPG_STATUS_TRUST_MARGINAL:
			trust = GPGValidityMarginal;
			break;
		case GPG_STATUS_TRUST_FULLY:
			trust = GPGValidityFull;
			break;
		case GPG_STATUS_TRUST_ULTIMATE:
			trust = GPGValidityUltimate;
			break;
	}
	self.hasFilled = YES;
}

- (void)getKeyIDAndUserIDFromPrompt:(NSString *)prompt {
	NSRange range = [prompt rangeOfString:@" "];
	self.fingerprint = [prompt substringToIndex:range.location];
	self.userID = unescapeString([prompt substringFromIndex:range.location + 1]);
}


- (id) init {
	if (self = [super init]) {
		status = 1;
	}
	return self;
}

- (void)dealloc {
	self.fingerprint = nil;
	self.primaryFingerprint = nil;
	self.userID = nil;
	self.creationDate = nil;
	self.expirationDate = nil;
	self.signatureClass = nil;
	[super dealloc];
}



@end
