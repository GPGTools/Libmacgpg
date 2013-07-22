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

 Additions by: Lukas Pitschl (@lukele) (c) 2013 
*/

#import "GPGKey.h"
#import "GPGTypesRW.h"

@implementation GPGKey

@synthesize subkeys=_subkeys, userIDs=_userIDs, fingerprint=_fingerprint, ownerTrust=_ownerTrust, secret=_secret, canSign=_canSign, canEncrypt=_canEncrypt, canCertify=_canCertify, canAuthenticate=_canAuthenticate, canAnySign=_canAnySign, canAnyEncrypt=_canAnyEncrypt, canAnyCertify=_canAnyCertify, canAnyAuthenticate=_canAnyAuthenticate, textForFilter=_textForFilter, primaryKey=_primaryKey, primaryUserID=_primaryUserID, keyID=_keyID, allFingerprints=_fingerprints, expirationDate=_expirationDate, creationDate=_creationDate, length=_length, disabled=_disabled, revoked=_revoked, invalid=_invalid, algorithm=_algorithm, validity=_validity;

- (instancetype)init {
	return [self initWithFingerprint:nil];
}

- (instancetype)initWithFingerprint:(NSString *)fingerprint {
	if(self = [super init]) {
		_fingerprint = [fingerprint copy];
	}
	return self;
}

- (void)setSubkeys:(NSArray *)subkeys {
	if(subkeys != _subkeys)
		[_subkeys release];
	
	_subkeys = [subkeys copy];
	// This gpg key will become the primary key of
	// each subkey.
	for(GPGKey *subkey in _subkeys)
		subkey.primaryKey = self;
}

- (void)setUserIDs:(NSArray *)userIDs {
	if(userIDs != _userIDs)
		[_userIDs release];
	
	_userIDs = [userIDs copy];
	self.primaryUserID = [_userIDs objectAtIndex:0];
}

- (NSString *)email {
	return self.primaryUserID.email;
}

- (NSString *)name {
	return self.primaryUserID.name;
}

- (NSString *)comment {
	return self.primaryUserID.comment;
}

- (BOOL)expired {
	return [self.expirationDate compare:[NSDate date]] == NSOrderedAscending;
}

- (NSString *)userIDDescription {
	return self.primaryUserID.userIDDescription;
}

- (NSImage *)photo {
	return self.primaryUserID.photo;
}

- (NSSet *)allFingerprints {
	static dispatch_once_t onceToken;
	
	__block GPGKey *weakSelf = self;
	
	dispatch_once(&onceToken, ^{
		NSMutableSet *fingerprints = [[NSMutableSet alloc] initWithCapacity:[self.subkeys count] + 1];
		[fingerprints addObject:weakSelf.fingerprint];
		if(self.subkeys)
			[fingerprints addObjectsFromArray:[weakSelf.subkeys valueForKey:@"fingerprint"]];
		weakSelf->_fingerprints = [fingerprints copy];
		[fingerprints release];
	});
	
	return [[_fingerprints retain] autorelease];
}

- (NSString *)textForFilter {
	static dispatch_once_t onceToken;
	
	__block GPGKey *weakSelf = self;
	
	dispatch_once(&onceToken, ^{
		NSMutableString *textForFilter = [[NSMutableString alloc] initWithCapacity:([weakSelf.subkeys count] * 40) + ([weakSelf.userIDs count] * 60) + 40];
		
		for(GPGKey *key in [weakSelf.subkeys arrayByAddingObject:weakSelf]) {
			[textForFilter appendFormat:@"0x%@\n0x%@\n0x%@\n", weakSelf.fingerprint, weakSelf.keyID, [weakSelf.keyID shortKeyID]];
		}
		for(GPGUserID *userID in weakSelf.userIDs)
			[textForFilter appendFormat:@"%@\n", userID.userIDDescription];
		weakSelf->_textForFilter = [textForFilter copy];
		[textForFilter release];
	});
	
	return [[_textForFilter retain] autorelease];
}

- (BOOL)isSubkey {
	return self.primaryKey != self;
}

- (NSString *)shortKeyID {
	return [self.keyID shortKeyID];
}

- (NSInteger)status {
	NSInteger status = self.ownerTrust;
	
	if (self.invalid) {
		status = GPGKeyStatus_Invalid;
	}
	if (self.revoked) {
		status += GPGKeyStatus_Revoked;
	}
	if (self.expired) {
		status += GPGKeyStatus_Expired;
	}
	if (self.disabled) {
		status += GPGKeyStatus_Disabled;
	}
	return status;
}

- (NSUInteger)hash {
	return [self.fingerprint hash];
}

- (BOOL)isEqual:(id)anObject {
	return [self.fingerprint isEqualToString:[anObject description]];
}

- (NSString *)description {
	return self.fingerprint;
}

- (void)dealloc {
	[_keyID release];
	_keyID = nil;
	[_fingerprint release];
	_fingerprint = nil;
	[_subkeys release];
	_subkeys = nil;
	[_userIDs release];
	_userIDs = nil;
	[_textForFilter release];
	_textForFilter = nil;
	[_fingerprints release];
	_fingerprints = nil;
	
	[_primaryKey release];
	_primaryKey = nil;
	[_primaryUserID release];
	_primaryUserID = nil;
	
	_secret = NO;
	_canEncrypt = NO;
	_canSign = NO;
	_ownerTrust = GPGValidityUnknown;
	
	[super dealloc];
}

//- (NSArray *)photos {
//	if (!photos) {
//		[self updatePhotos];
//	}
//	return [[photos retain] autorelease];
//}
//- (void)updatePhotos {
//
//	GPGTask *gpgTask = [GPGTask gpgTask];
//	[gpgTask addArgument:@"-k"];
//	[gpgTask addArgument:fingerprint];
//	gpgTask.getAttributeData = YES;
//
//	if ([gpgTask start] != 0) {
//		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Update photos failed!") gpgTask:gpgTask];
//	}
//
//
//	NSData *attributeData = gpgTask.attributeData;
//	NSArray *outLines = [gpgTask.outText componentsSeparatedByString:@"\n"];
//	NSArray *statusLines = [gpgTask.statusText componentsSeparatedByString:@"\n"];
//
//
//
//	NSMutableArray *thePhotos = [NSMutableArray array];
//
//	NSArray *statusFields, *colons;
//	NSInteger pos = 0, dataLength, photoStatus;
//	int curOutLine = 0, countOutLines = [outLines count];
//	NSString *outLine, *photoHash;
//
//	for (NSString *statuLine in statusLines) {
//		if ([statuLine hasPrefix:@"[GNUPG:] ATTRIBUTE "]) {
//			photoHash = nil;
//			for (; curOutLine < countOutLines; curOutLine++) {
//				outLine = [outLines objectAtIndex:curOutLine];
//				if ([outLine hasPrefix:@"uat:"]) {
//					colons = [outLine componentsSeparatedByString:@":"];
//					photoHash = [colons objectAtIndex:7];
//					photoStatus = [[colons objectAtIndex:1] isEqualToString:@"r"] ? GPGKeyStatus_Revoked : 0;
//					curOutLine++;
//					break;
//				}
//			}
//			statusFields = [statuLine componentsSeparatedByString:@" "];
//			dataLength = [[statusFields objectAtIndex:3] integerValue];
//			if ([[statusFields objectAtIndex:4] isEqualToString:@"1"]) { //1 = Bild
//				if (photoHash && ![thePhotos containsObject:photoHash]) {
//					NSImage *aPhoto = [[NSImage alloc] initWithData:[attributeData subdataWithRange:(NSRange) {pos + 16, dataLength - 16}]];
//					if (aPhoto) {
//						NSImageRep *imageRep = [[aPhoto representations] objectAtIndex:0];
//						NSSize size = imageRep.size;
//						if (size.width != imageRep.pixelsWide || size.height != imageRep.pixelsHigh) {
//							size.width = imageRep.pixelsWide;
//							size.height = imageRep.pixelsHigh;
//							imageRep.size = size;
//							[aPhoto setSize:size];
//						}
//
//
//						GPGPhotoID *photoID = [[GPGPhotoID alloc] initWithImage:aPhoto hashID:photoHash status:photoStatus];
//
//						[thePhotos addObject:photoID];
//						[photoID release];
//						[aPhoto release];
//					}
//				}
//			}
//			pos += dataLength;
//		}
//	}
//	self.photos = thePhotos;
//}


//- (void)updatePreferences {
//
//	GPGTask *gpgTask = [GPGTask gpgTask];
//	[gpgTask addArgument:@"--edit-key"];
//	[gpgTask addArgument:fingerprint];
//	[gpgTask addArgument:@"quit"];
//
//	if ([gpgTask start] != 0) {
//		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Update preferences failed!") gpgTask:gpgTask];
//	}
//
//
//	NSArray *lines = [gpgTask.outText componentsSeparatedByString:@"\n"];
//
//	NSInteger i = 0, c = [userIDs count];
//	for (NSString *line in lines) {
//		if ([line hasPrefix:@"uid:"]) {
//			if (i >= c) {
//				GPGDebugLog(@"updatePreferences: index >= count!");
//				break;
//			}
//			[[userIDs objectAtIndex:i] updatePreferences:line];
//			i++;
//		}
//	}
//}
//

@end
