/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "GPGKey.h"
#import "GPGTask.h"


@implementation GPGKey

+ (id)keyWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	return [[[[self class] alloc] initWithListing:listing fingerprint:aFingerprint isSecret:isSec  withSigs:withSigs] autorelease];
}
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs {
	if (self = [super init]) {
		self.children = [NSMutableArray arrayWithCapacity:2];
		self.subkeys = [NSMutableArray arrayWithCapacity:1];
		self.userIDs = [NSMutableArray arrayWithCapacity:1];
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
	
	secret = isSec;
	
	
	NSUInteger i = 1, c = [listing count];
	splitedLine = [[listing objectAtIndex:0] componentsSeparatedByString:@":"];
	
	[self updateWithLine:splitedLine];

	ownerTrust = [[self class] validityFromLetter:[splitedLine objectAtIndex:8]];
	
	
	tempItem = [splitedLine objectAtIndex:11];
	disabled = [tempItem rangeOfString:@"D"].length > 0;
	
	
	primaryUserID = nil;
	
	
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
					[self removeObjectFromUserIDsAtIndex:anIndex];
					[self insertObject:userIDChild inUserIDsAtIndex:userIDIndex];
				}
				[userIDsToRemove removeObject:userIDChild];
			} else {
				userIDChild = [[GPGUserID alloc] initWithListing:splitedLine signatureListing:sigListing parentKey:self];
				
				[self insertObject:userIDChild inUserIDsAtIndex:userIDIndex];
				[self insertObject:userIDChild inChildrenAtIndex:userIDIndex];
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
					[self removeObjectFromSubkeysAtIndex:anIndex];
					[self insertObject:subkeyChild inSubkeysAtIndex:subkeyIndex];
				}
				[subkeysToRemove removeObject:subkeyChild];
			} else {
				subkeyChild = [[GPGSubkey alloc] initWithListing:splitedLine fingerprint:aFingerprint parentKey:self];
				
				[self insertObject:subkeyChild inSubkeysAtIndex:subkeyIndex];
				[self insertObject:subkeyChild inChildrenAtIndex:userIDs.count + subkeyIndex];
				
			}
			subkeyChild.index = subkeyIndex++;
		}
	}
	
	
	[self removeObjectsFromUserIDsIdenticalTo:userIDsToRemove];
	[self removeObjectsFromChildrenIdenticalTo:userIDsToRemove];
	[self removeObjectsFromSubkeysIdenticalTo:subkeysToRemove];
	[self removeObjectsFromChildrenIdenticalTo:subkeysToRemove];

	
	NSUInteger userIDsCount = userIDs.count;
	for (subkeyChild in subkeys) {
		subkeyChild.index += userIDsCount;
	}
	
	self.photos = nil;
	
	[self updateFilterText];
}




- (void)updateFilterText { // Muss für den Schlüssel aufgerufen werden, bevor auf textForFilter zugegriffen werden kann!
	NSMutableString *newText = [NSMutableString stringWithCapacity:200];
	
	[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", [self fingerprint], [self keyID], [self shortKeyID]];
	for (GPGSubkey *subkey in self.subkeys) {
		[newText appendFormat:@"0x%@\n0x%@\n0x%@\n", [subkey fingerprint], [subkey keyID], [subkey shortKeyID]];
	}
	for (GPGUserID *userID in self.userIDs) {
		[newText appendFormat:@"%@\n", [userID userID]];
	}
	
	[textForFilter release];
	textForFilter = [newText copy];
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
		@throw gpgTaskException(GPGTaskException, @"Update photos failed!", GPGErrorTaskException, gpgTask);
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
	photos = [thePhotos retain];
}


- (void)updatePreferences {

	GPGTask *gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:fingerprint];
	[gpgTask addArgument:@"quit"];
	
	if ([gpgTask start] != 0) {
		@throw gpgTaskException(GPGTaskException, @"Update preferences failed!", GPGErrorTaskException, gpgTask);
	}
	
	
	NSArray *lines = [gpgTask.outText componentsSeparatedByString:@"\n"];
	
	NSInteger i = 0, c = [userIDs count];
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"]) {
			if (i >= c) {
				NSLog(@"updatePreferences: index >= count!");				
				break;
			}
			[[userIDs objectAtIndex:i] updatePreferences:line];
			i++;
		}
	}
}





+ (void)splitUserID:(NSString *)aUserID intoName:(NSString **)namePtr email:(NSString **)emailPtr comment:(NSString **)commentPtr {
	if (!aUserID) {
		*namePtr = nil;
		*emailPtr = nil;
		*commentPtr = nil;
		return;
	}
	NSString *workText = aUserID;
	NSUInteger textLength = [workText length];
	NSRange range;
	
	range = [workText rangeOfString:@" <" options:NSBackwardsSearch];
	if ([workText hasSuffix:@">"] && range.length > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		*emailPtr = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
		textLength -= (range.length + 3);
	} else {
		*emailPtr = nil;
	}
	
	range = [workText rangeOfString:@" (" options:NSBackwardsSearch];
	if ([workText hasSuffix:@")"] && range.length > 0 && range.location > 0) {
		range.location += 2;
		range.length = textLength - range.location - 1;
		*commentPtr = [workText substringWithRange:range];
		
		workText = [workText substringToIndex:range.location - 2];
	} else {
		*commentPtr = nil;
	}
	
	*namePtr = workText;
}




@synthesize photos;
@synthesize textForFilter;
@synthesize fingerprint;
@synthesize ownerTrust;
@synthesize secret;
@synthesize primaryUserID;


- (GPGKey *)primaryKey { return self; }
- (NSString *)type { return secret ? @"sec" : @"pub"; }
- (NSInteger)index { return 0; }

- (NSString *)userID { return primaryUserID.userID; }
- (NSString *)name { return primaryUserID.name; }
- (NSString *)email { return primaryUserID.email; }
- (NSString *)comment { return primaryUserID.comment; }


- (BOOL)safe {
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
}


- (void)setChildren:(NSMutableArray *)value {
	if (value != children) {
		[children release];
		children = [value retain];
	}
}
- (NSArray *)children {
	return [[children retain] autorelease];
}
- (unsigned)countOfChildren {
	return [children count];
}
- (id)objectInChildrenAtIndex:(unsigned)theIndex {
	return [children objectAtIndex:theIndex];
}
- (void)getChildren:(id *)objsPtr range:(NSRange)range {
	[children getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inChildrenAtIndex:(unsigned)theIndex {
	[children insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromChildrenAtIndex:(unsigned)theIndex {
	[children removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInChildrenAtIndex:(unsigned)theIndex withObject:(id)obj {
	[children replaceObjectAtIndex:theIndex withObject:obj];
}
- (void)removeObjectsFromChildrenIdenticalTo:(id <NSFastEnumeration>)objects {
	NSIndexSet *indexes = [children indexesOfIdenticalObjects:objects];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"children"];
	[children removeObjectsAtIndexes:indexes];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"children"];
}


- (void)setSubkeys:(NSMutableArray *)value {
	if (value != subkeys) {
		[subkeys release];
		subkeys = [value retain];
	}
}
- (NSArray *)subkeys {
	return [[subkeys retain] autorelease];
}
- (unsigned)countOfSubkeys {
	return [subkeys count];
}
- (id)objectInSubkeysAtIndex:(unsigned)theIndex {
	return [subkeys objectAtIndex:theIndex];
}
- (void)getSubkeys:(id *)objsPtr range:(NSRange)range {
	[subkeys getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inSubkeysAtIndex:(unsigned)theIndex {
	[subkeys insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromSubkeysAtIndex:(unsigned)theIndex {
	[subkeys removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInSubkeysAtIndex:(unsigned)theIndex withObject:(id)obj {
	[subkeys replaceObjectAtIndex:theIndex withObject:obj];
}
- (void)removeObjectsFromSubkeysIdenticalTo:(id <NSFastEnumeration>)objects {
	NSIndexSet *indexes = [subkeys indexesOfIdenticalObjects:objects];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"subkeys"];
	[subkeys removeObjectsAtIndexes:indexes];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"subkeys"];
}

								  
- (void)setUserIDs:(NSMutableArray *)value {
	if (value != userIDs) {
		[userIDs release];
		userIDs = [value retain];
	}
}
- (NSArray *)userIDs {
	return [[userIDs retain] autorelease];
}
- (unsigned)countOfUserIDs {
	return [userIDs count];
}
- (id)objectInUserIDsAtIndex:(unsigned)theIndex {
	return [userIDs objectAtIndex:theIndex];
}
- (void)getUserIDs:(id *)objsPtr range:(NSRange)range {
	[userIDs getObjects:objsPtr range:range];
}
- (void)insertObject:(id)obj inUserIDsAtIndex:(unsigned)theIndex {
	[userIDs insertObject:obj atIndex:theIndex];
}
- (void)removeObjectFromUserIDsAtIndex:(unsigned)theIndex {
	[userIDs removeObjectAtIndex:theIndex];
}
- (void)replaceObjectInUserIDsAtIndex:(unsigned)theIndex withObject:(id)obj {
	[userIDs replaceObjectAtIndex:theIndex withObject:obj];
}
- (void)removeObjectsFromUserIDsIdenticalTo:(id <NSFastEnumeration>)objects {
	NSIndexSet *indexes = [userIDs indexesOfIdenticalObjects:objects];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"userIDs"];
	[userIDs removeObjectsAtIndexes:indexes];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"userIDs"];
}


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
	self.textForFilter = nil;;
	
	self.fingerprint = nil;
	
	[super dealloc];
}



@end
