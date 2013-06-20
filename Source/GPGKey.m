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

#import "GPGKey.h"
#import "GPGTask.h"
#import "GPGException.h"

@interface GPGKey ()

@property (nonatomic, retain) NSArray *userIDs;
@property (nonatomic, retain) NSArray *subkeys;
@property (nonatomic, retain) NSArray *children;
@property (nonatomic, retain) NSArray *photos;
@property (nonatomic, retain) NSString *fingerprint;
@property (nonatomic) GPGValidity ownerTrust;
@property (nonatomic) BOOL secret;


- (void)updateFilterText;
- (void)updatePhotos;

@end



@implementation GPGKey
@synthesize userIDs, subkeys, children, photos, textForFilter, fingerprint, ownerTrust, secret, primaryUserID;

+ (id)keyWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	return [[[[self class] alloc] initWithListing:listing fingerprint:aFingerprint isSecret:isSec  withSigs:withSigs] autorelease];
}
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	if (self = [super init]) {
		self.fingerprint = aFingerprint;
		
		[self updateWithListing:listing isSecret:isSec withSigs:withSigs];
	}
	return self;	
}
- (id)init {
	return [self initWithListing:nil fingerprint:nil isSecret:NO withSigs:NO]; 
}
- (void)updateWithListing:(NSArray *)listing isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	NSString *tempItem, *aHash, *aFingerprint;
	NSArray *splitedLine;
	GPGSubkey *subkeyChild;
	GPGUserID *userIDChild;
	NSUInteger subkeyIndex = 0, userIDIndex = 0;
	
	self.secret = isSec;
	
	NSUInteger i = 1, c = [listing count];
	splitedLine = [[listing objectAtIndex:0] componentsSeparatedByString:@":"];
	
	[self updateWithLine:splitedLine];

	self.ownerTrust = [[self class] validityFromLetter:[splitedLine objectAtIndex:8]];
	
	
	tempItem = [splitedLine objectAtIndex:11];
	disabled = [tempItem rangeOfString:@"D"].length > 0;
	
	
	primaryUserID = nil;
	
	
	NSMutableArray *newUserIDs = [NSMutableArray arrayWithArray:userIDs];
	NSMutableArray *newSubkeys = [NSMutableArray arrayWithArray:subkeys];
	
	NSMutableSet *subkeysToRemove = [NSMutableSet setWithArray:subkeys];
	NSMutableSet *userIDsToRemove = [NSMutableSet setWithArray:userIDs];
	
	
	for	(; i < c; i++) {
		splitedLine = [[listing objectAtIndex:i] componentsSeparatedByString:@":"];
		
		tempItem = [splitedLine objectAtIndex:0];
		if ([tempItem isEqualToString:@"uid"]) {
			NSArray *sigListing = nil;
			NSUInteger numSigs = 0;
			
			for (; i + numSigs + 1 < c; numSigs++) {
				NSString *line = [listing objectAtIndex:i + numSigs + 1];
				if (![line hasPrefix:@"sig:"] && ![line hasPrefix:@"rev:"] && ![line hasPrefix:@"spk:"]) {
					break;
				}
			}
			
			if (numSigs > 0) {
				sigListing = [listing subarrayWithRange:(NSRange){i + 1, numSigs}];
			} else if (withSigs) {
				sigListing = [NSArray array];
			}
			
			aHash = [splitedLine objectAtIndex:7];
			userIDChild = [userIDsToRemove member:aHash];
			
			if (userIDChild) {
				NSUInteger anIndex = [userIDs indexOfObjectIdenticalTo:userIDChild];
				[userIDChild updateWithListing:splitedLine signatureListing:sigListing];
				if (anIndex != userIDIndex) {
					[newUserIDs removeObjectAtIndex:anIndex];
				}
				[userIDsToRemove removeObject:userIDChild];
			} else {
				userIDChild = [[[GPGUserID alloc] initWithListing:splitedLine signatureListing:sigListing parentKey:self] autorelease];
				
				[newUserIDs insertObject:userIDChild atIndex:userIDIndex];
			}
			if (!primaryUserID) {
				primaryUserID = userIDChild;
			}
			userIDChild.index = userIDIndex++;
			
		} else if ([tempItem isEqualToString:@"sub"]) {
			aFingerprint = [[[listing objectAtIndex:++i] componentsSeparatedByString:@":"] objectAtIndex:9];
			subkeyChild = [subkeysToRemove member:aFingerprint];
			
			if (subkeyChild) {
				NSUInteger anIndex = [subkeys indexOfObjectIdenticalTo:subkeyChild];
				[subkeyChild updateWithListing:splitedLine];
				if (anIndex != subkeyIndex) {
					[newSubkeys removeObjectAtIndex:anIndex];
				}
				[subkeysToRemove removeObject:subkeyChild];
			} else {
				subkeyChild = [[[GPGSubkey alloc] initWithListing:splitedLine fingerprint:aFingerprint parentKey:self] autorelease];
				
				[newSubkeys insertObject:subkeyChild atIndex:subkeyIndex];				
			}
			subkeyChild.index = subkeyIndex++;
		}
	}
	
	
	NSIndexSet *indexes = [newUserIDs indexesOfIdenticalObjects:userIDsToRemove];
	[newUserIDs removeObjectsAtIndexes:indexes];
	
	indexes = [newSubkeys indexesOfIdenticalObjects:subkeysToRemove];
	[newSubkeys removeObjectsAtIndexes:indexes];

	NSMutableArray *newChildren = [NSMutableArray arrayWithArray:newUserIDs];
	[newChildren addObjectsFromArray:newSubkeys];
	
	
	self.userIDs = newUserIDs;
	self.subkeys = newSubkeys;
	self.children = newChildren;

	
	NSUInteger userIDsCount = userIDs.count;
	for (subkeyChild in subkeys) {
		subkeyChild.index += userIDsCount;
	}
	
	self.photos = nil;
	
	filterTextOnceToken = 0;
}






- (NSString *)textForFilter {
	[self updateFilterText];
	return [[textForFilter retain] autorelease];
}
- (NSString *)allFingerprints {
	[self updateFilterText];
	return [[allFingerprints retain] autorelease];
}

- (void)updateFilterText {
	__block typeof(self) weakSelf = self;
	dispatch_once(&filterTextOnceToken, ^{
		NSMutableString *newText = [[NSMutableString alloc] initWithCapacity:weakSelf->subkeys.count * 40 + weakSelf->userIDs.count * 60 + 40];
		NSMutableString *fingerprints = [[NSMutableString alloc] initWithCapacity:weakSelf->subkeys.count * 40 + 40];
		
		[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", weakSelf.fingerprint, weakSelf.keyID, weakSelf.shortKeyID];
		[fingerprints appendFormat:@"%@\n", weakSelf.fingerprint];
		for (GPGSubkey *subkey in weakSelf->subkeys) {
			[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", [subkey fingerprint], [subkey keyID], [subkey shortKeyID]];
			[fingerprints appendFormat:@"%@\n", [subkey fingerprint]];
		}
		for (GPGUserID *userID in weakSelf->userIDs) {
			[newText appendFormat:@"%@\n", [userID userID]];
		}
		
		id old = weakSelf->textForFilter;
		weakSelf->textForFilter = newText;
		[old release];
		
		old = weakSelf->allFingerprints;
		weakSelf->allFingerprints = fingerprints;
		[old release];
    });
}

- (NSArray *)photos {
	if (!photos) {
		[self updatePhotos];
	}
	return [[photos retain] autorelease];
}
- (void)updatePhotos {

	GPGTask *gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:fingerprint];
	gpgTask.getAttributeData = YES;
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Update photos failed!") gpgTask:gpgTask];
	}
	
	
	NSData *attributeData = gpgTask.attributeData;
	NSArray *outLines = [gpgTask.outText componentsSeparatedByString:@"\n"];
	NSArray *statusLines = [gpgTask.statusText componentsSeparatedByString:@"\n"];
	
	
	
	NSMutableArray *thePhotos = [NSMutableArray array];
	
	NSArray *statusFields, *colons;
	NSInteger pos = 0, dataLength, photoStatus;
	int curOutLine = 0, countOutLines = [outLines count];
	NSString *outLine, *photoHash;
	
	for (NSString *statuLine in statusLines) {
		if ([statuLine hasPrefix:@"[GNUPG:] ATTRIBUTE "]) {
			photoHash = nil;
			for (; curOutLine < countOutLines; curOutLine++) {
				outLine = [outLines objectAtIndex:curOutLine];
				if ([outLine hasPrefix:@"uat:"]) {
					colons = [outLine componentsSeparatedByString:@":"];
					photoHash = [colons objectAtIndex:7];
					photoStatus = [[colons objectAtIndex:1] isEqualToString:@"r"] ? GPGKeyStatus_Revoked : 0;
					curOutLine++;
					break;
				}
			}
			statusFields = [statuLine componentsSeparatedByString:@" "];
			dataLength = [[statusFields objectAtIndex:3] integerValue];
			if ([[statusFields objectAtIndex:4] isEqualToString:@"1"]) { //1 = Bild
				if (photoHash && ![thePhotos containsObject:photoHash]) {
					NSImage *aPhoto = [[NSImage alloc] initWithData:[attributeData subdataWithRange:(NSRange) {pos + 16, dataLength - 16}]];
					if (aPhoto) {
						NSImageRep *imageRep = [[aPhoto representations] objectAtIndex:0];
						NSSize size = imageRep.size;
						if (size.width != imageRep.pixelsWide || size.height != imageRep.pixelsHigh) {
							size.width = imageRep.pixelsWide;
							size.height = imageRep.pixelsHigh;
							imageRep.size = size;
							[aPhoto setSize:size];
						}
						
						
						GPGPhotoID *photoID = [[GPGPhotoID alloc] initWithImage:aPhoto hashID:photoHash status:photoStatus];
						
						[thePhotos addObject:photoID];
						[photoID release];
						[aPhoto release];
					}					
				}
			}
			pos += dataLength;
		}
	}
	self.photos = thePhotos;
}


- (void)updatePreferences {

	GPGTask *gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:fingerprint];
	[gpgTask addArgument:@"quit"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Update preferences failed!") gpgTask:gpgTask];
	}
	
	
	NSArray *lines = [gpgTask.outText componentsSeparatedByString:@"\n"];
	
	NSInteger i = 0, c = [userIDs count];
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"]) {
			if (i >= c) {
				GPGDebugLog(@"updatePreferences: index >= count!");				
				break;
			}
			[[userIDs objectAtIndex:i] updatePreferences:line];
			i++;
		}
	}
}



+ (void)setInfosWithUserID:(NSString *)aUserID toObject:(NSObject <GPGUserIDProtocol> *)object {
	if (!aUserID) {
		object.name = nil;
		object.email = nil;
		object.comment = nil;
		return;
	}
	
	NSString *workText = aUserID;
	NSUInteger textLength = [workText length];
	NSRange range;
	
	range = [workText rangeOfString:@" <" options:NSBackwardsSearch];
	if ([workText hasSuffix:@">"] && range.length > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		object.email = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
		textLength -= (range.length + 3);
	} else {
		object.email = nil;
	}
	
	range = [workText rangeOfString:@" (" options:NSBackwardsSearch];
	if ([workText hasSuffix:@")"] && range.length > 0 && range.location > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		object.comment = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
	} else {
		object.comment = nil;
	}
	
	object.name = workText;
}





- (GPGKey *)primaryKey { return self; }
- (NSString *)type { return secret ? @"sec" : @"pub"; }
- (NSInteger)index { return 0; }

- (NSString *)userID { return primaryUserID.userID; }
- (NSString *)name { return primaryUserID.name; }
- (NSString *)email { return primaryUserID.email; }
- (NSString *)comment { return primaryUserID.comment; }


/*- (BOOL)safe {
	if (length < 1536) { //Länge des Hauptschlüssels.
		return NO;
	}
	
	for (GPGSubkey *aSubkey in subkeys) {
		if (aSubkey.length < 1536 && aSubkey.status == 0) { //Länge der gültigen Unterschlüssel.
			return NO;
		}
	}
	
	for (GPGUserID *aUserID in userIDs) {
		if ([[aUserID digestPreferences] count] > 0) { //Standard Hashalgorithmus der Benutzer IDs.
			switch ([[[aUserID.digestPreferences objectAtIndex:0] substringFromIndex:1] integerValue]) {
				case 1: //MD5
				case 2: //SHA1
					return NO;
			}
		}
	}
	
	return YES;
}*/



- (NSUInteger)hash {
	return [fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[fingerprint retain] autorelease];
}

- (void)dealloc {
	self.children = nil;
	self.subkeys = nil;
	self.userIDs = nil;
	self.photos = nil;
	
	[textForFilter release];
	[allFingerprints release];
	
	self.fingerprint = nil;
	
	[super dealloc];
}



@end
