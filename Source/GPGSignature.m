/*
 Copyright © Roman Zechmeister, 2013
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import <Libmacgpg/GPGSignature.h>
#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGTransformer.h>
#import <Libmacgpg/GPGTypesRW.h>

@implementation GPGSignature

@synthesize trust=_trust, status=_status, fingerprint=_fingerprint, creationDate=_creationDate, expirationDate=_expirationDate, version=_version, publicKeyAlgorithm=_publicKeyAlgorithm, hashAlgorithm=_hashAlgorithm, primaryKey=_primaryKey;

- (instancetype)init {
	return [self initWithFingerprint:nil status:GPGErrorGeneralError];
}

- (instancetype)initWithFingerprint:(NSString *)fingerprint status:(GPGErrorCode)status {
	if(self = [super init]) {
		_fingerprint = [fingerprint copy];
		_status = status;
	}
	return self;
}

- (NSString *)userIDDescription {
	return self.primaryKey.userIDDescription;
}

- (NSString *)name {
	return self.primaryKey.name;
}

- (NSString *)email {
	return self.primaryKey.email;
}

- (NSString *)comment {
	return self.primaryKey.comment;
}

- (NSString *)primaryFingerprint {
	return self.primaryKey.fingerprint;
}

- (NSImage *)photo {
	return self.primaryKey.photo;
}

//- (void)addInfoFromStatusCode:(NSInteger)statusCode andPrompt:(NSString *)prompt  {
//	if (statusCode == GPG_STATUS_NEWSIG) {
//		return;
//	}	
//	NSArray *components = [prompt componentsSeparatedByString:@" "];
//	
//	switch (statusCode) {
//		case GPG_STATUS_NEWSIG:
//			break;
//		case GPG_STATUS_GOODSIG:
//			self.status = GPGErrorNoError;
//			[self getKeyIDAndUserIDFromPrompt:prompt];
//			break;
//		case GPG_STATUS_EXPSIG:
//			self.status = GPGErrorSignatureExpired;
//			[self getKeyIDAndUserIDFromPrompt:prompt];
//			break;
//		case GPG_STATUS_EXPKEYSIG:
//			self.status = GPGErrorKeyExpired;
//			[self getKeyIDAndUserIDFromPrompt:prompt];
//			break;
//		case GPG_STATUS_BADSIG:
//			self.status = GPGErrorBadSignature;
//			[self getKeyIDAndUserIDFromPrompt:prompt];
//			break;
//		case GPG_STATUS_REVKEYSIG:
//			self.status = GPGErrorCertificateRevoked;
//			[self getKeyIDAndUserIDFromPrompt:prompt];
//			break;
//		case GPG_STATUS_ERRSIG: {
//			self.fingerprint = [components objectAtIndex:0];
//			self.publicKeyAlgorithm = [[components objectAtIndex:1] intValue];
//			self.hashAlgorithm = [[components objectAtIndex:2] intValue];
//			self.signatureClass = [components objectAtIndex:3];
//			self.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:4]];
//			int rc = [[components objectAtIndex:5] intValue];
//			if (rc == 4) {
//				self.status = GPGErrorUnknownAlgorithm;
//			} else if (rc == 9) {
//				self.status = GPGErrorNoPublicKey;
//			} else {
//				self.status = GPGErrorGeneralError;
//			}
//			
//			break; }
//
//	
//		
//		case GPG_STATUS_VALIDSIG:
//			self.fingerprint = [components objectAtIndex:0];
//			self.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:2]];
//			self.expirationDate = [NSDate dateWithGPGString:[components objectAtIndex:3]];
//			self.version = [[components objectAtIndex:4] intValue];
//			self.publicKeyAlgorithm = [[components objectAtIndex:6] intValue];
//			self.hashAlgorithm = [[components objectAtIndex:7] intValue];
//			self.signatureClass = [components objectAtIndex:8];
//			if ([components count] >= 10) {
//				self.primaryFingerprint = [components objectAtIndex:9];
//			}
//			break;
//			
//			
//		case GPG_STATUS_TRUST_UNDEFINED:
//			self.trust = GPGValidityUndefined;
//			break;
//		case GPG_STATUS_TRUST_NEVER:
//			self.trust = GPGValidityNever;
//			break;
//		case GPG_STATUS_TRUST_MARGINAL:
//			self.trust = GPGValidityMarginal;
//			break;
//		case GPG_STATUS_TRUST_FULLY:
//			self.trust = GPGValidityFull;
//			break;
//		case GPG_STATUS_TRUST_ULTIMATE:
//			self.trust = GPGValidityUltimate;
//			break;
//	}
//	self.hasFilled = YES;
//}

//- (void)getKeyIDAndUserIDFromPrompt:(NSString *)prompt {
//	NSRange range = [prompt rangeOfString:@" "];
//	self.fingerprint = [prompt substringToIndex:range.location];
//	self.userID = [[prompt substringFromIndex:range.location + 1] unescapedString];
//}

- (void)dealloc {
	_trust = GPGValidityUnknown;
	_status = GPGErrorGeneralError;
	
	[_fingerprint release];
	_fingerprint = nil;
	[_creationDate release];
	_creationDate = nil;
	[_expirationDate release];
	_expirationDate = nil;
	_version = 0;
	_publicKeyAlgorithm = 0;
	_hashAlgorithm = 0;
	
	_primaryKey = nil;
	
	[super dealloc];
}

- (NSString *)humanReadableDescription {
    return [self humanReadableDescriptionShouldLocalize:YES];
}

#define maybeLocalize(key) (shouldLocalize ? localizedLibmacgpgString(key) : key)

- (NSString *)humanReadableDescriptionShouldLocalize:(BOOL)shouldLocalize {
    NSString *sigStatus;
    switch (self.status) {
        case GPGErrorNoError:
            sigStatus = maybeLocalize(@"Signed");
            break;
        case GPGErrorSignatureExpired:
        case GPGErrorKeyExpired:
            sigStatus = maybeLocalize(@"Signature expired");
            break;
        case GPGErrorCertificateRevoked:
            sigStatus = maybeLocalize(@"Signature revoked");
            break;
        case GPGErrorUnknownAlgorithm:
            sigStatus = maybeLocalize(@"Unverifiable signature");
            break;
        case GPGErrorNoPublicKey:
            sigStatus = maybeLocalize(@"Signed by stranger");
            break;
        case GPGErrorBadSignature:
            sigStatus = maybeLocalize(@"Bad signature");
            break;
        default:
            sigStatus = maybeLocalize(@"Signature error");
            break;
    }
    
    NSMutableString *desc = [NSMutableString stringWithString:sigStatus];
    if (self.userIDDescription && [self.userIDDescription length]) {
        [desc appendFormat:@" (%@)", self.userIDDescription];
    }
    else if (self.fingerprint && [self.fingerprint length]) {
        GPGKeyAlgorithmNameTransformer *algTransformer = [[GPGKeyAlgorithmNameTransformer alloc] init];
        algTransformer.keepUnlocalized = !shouldLocalize;

        NSString *algorithmDesc = [algTransformer transformedIntegerValue:self.publicKeyAlgorithm];
        [desc appendFormat:@" (%@ %@)", self.fingerprint, algorithmDesc];
        [algTransformer release];
    }
    
    return desc;
}

@end
