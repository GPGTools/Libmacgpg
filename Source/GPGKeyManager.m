#import "Libmacgpg.h"
#import "GPGKeyManager.h"
#import "GPGTypesRW.h"
#include <sys/time.h>

NSString * const GPGKeyManagerKeysDidChangeNotification = @"GPGKeyManagerKeysDidChangeNotification";

@interface GPGKeyManager ()

@property (copy, readwrite) NSDictionary *keysByKeyID;
@property (copy, readwrite) NSSet *publicKeys;
@property (copy, readwrite) NSSet *secretKeys;

@end

@implementation GPGKeyManager

@synthesize allKeys=_allKeys, keysByKeyID=_keysByKeyID, publicKeys=_publicKeys, secretKeys=_secretKeys, completionQueue=_completionQueue;

- (void)loadAllKeys {
	[self loadKeys:nil fetchSignatures:NO fetchUserAttributes:NO];
}

- (void)loadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchUserAttributes:(BOOL)fetchUserAttributes {
	dispatch_sync(_keyLoadingQueue, ^{
		[self _loadKeys:keys fetchSignatures:fetchSignatures fetchUserAttributes:fetchUserAttributes];
	});
}

- (void)_loadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchUserAttributes:(BOOL)fetchUserAttributes {
	NSSet *newKeysSet = nil;
	
	//NSLog(@"[%@]: Loading keys!", [NSThread currentThread]);
	@try {
		NSArray *keyArguments = [[keys valueForKey:@"description"] allObjects];
		
        dispatch_queue_t dispatchQueue = dispatch_queue_create("org.gpgtools.libmacgpg._loadKeys.gpgTask", DISPATCH_QUEUE_CONCURRENT);
		dispatch_group_t dispatchGroup = dispatch_group_create();
		
		_fetchSignatures = fetchSignatures;
		_fetchUserAttributes = fetchUserAttributes;
		
		
		
		dispatch_group_async(dispatchGroup, dispatchQueue, ^{
			// Get all fingerprints of the secret keys.
			GPGTask *gpgTask = [GPGTask gpgTask];
			gpgTask.batchMode = YES;
			[gpgTask addArgument:@"--list-secret-keys"];
			[gpgTask addArgument:@"--with-fingerprint"];
			[gpgTask addArguments:keyArguments];
			
			[gpgTask start];
			
			self->_secKeyFingerprints = [[self fingerprintsFromColonListing:gpgTask.outText] retain];
			
		});
		
		
		// Get the infos from gpg.
		GPGTask *gpgTask = [GPGTask gpgTask];
		if (fetchSignatures) {
			[gpgTask addArgument:@"--list-sigs"];
			[gpgTask addArgument:@"--list-options"];
			[gpgTask addArgument:@"show-sig-subpackets=29"];
		} else {
			[gpgTask addArgument:@"--list-keys"];
		}
		if (fetchUserAttributes) {
			_attributeInfos = [[NSMutableDictionary alloc] init];
			_attributeDataLocation = 0;
			gpgTask.getAttributeData = YES;
		}
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:keyArguments];
		
		
		[gpgTask start];
		
		
		dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
		
		
		
		// ======= Parsing =======
		
		NSMutableArray *newKeys = [[NSMutableArray alloc] init];
		
		
		_attributeData = [gpgTask.attributeData retain]; //attributeData is only needed for UATs (PhotoID).
		
		_keyLines = [gpgTask.outText componentsSeparatedByString:@"\n"];
		NSUInteger index = 0, count = _keyLines.count;
		NSInteger pubStart = -1;
		
		for (; index < count; index++) {
			NSString *line = [_keyLines objectAtIndex:index];
			if ([line hasPrefix:@"pub"] || line.length == 0) {
				if (pubStart > -1) {
					GPGKey *key = [[GPGKey alloc] init];
					[newKeys addObject:key];
					[key release];
					
					dispatch_group_async(dispatchGroup, dispatchQueue, ^{
						[self fillKey:key withRange:NSMakeRange(pubStart, index - pubStart)];
					});
				}
				pubStart = index;
			}
		}
		
		
		dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        dispatch_release(dispatchGroup);
        dispatch_release(dispatchQueue);
		
		[_attributeData release];
		
		newKeysSet = [NSSet setWithArray:newKeys];
		[newKeys release];
		
		[_mutableAllKeys minusSet:keys];
		[_mutableAllKeys minusSet:newKeysSet];
		[_mutableAllKeys unionSet:newKeysSet];
		
		_once_keysByKeyID = 0;
		
		if (fetchSignatures) {
			NSDictionary *keysByKeyID = self.keysByKeyID;
			
			for (GPGKey *key in _mutableAllKeys) {
				for (GPGUserID *uid in key.userIDs) {
					for (GPGUserIDSignature *sig in uid.signatures) {
						sig.primaryKey = [keysByKeyID objectForKey:sig.keyID]; // Set the key used to create the signature.
					}
				}
			}
		}
		
	}
	@catch (NSException *exception) {
		//TODO: Detect unavailable keyring.
		
		GPGDebugLog(@"loadKeys failed: %@", exception);
		_mutableAllKeys = nil;
#ifdef DEBUGGING
		@throw exception;
#endif
	}
	@finally {
		[_secKeyFingerprints release];
		_secKeyFingerprints = nil;
		
		NSSet *oldAllKeys = _allKeys;
		_allKeys = [_mutableAllKeys copy];
		[oldAllKeys release];
	}
	
	
	// Let's check if the keys need to be reloaded again, as they have changed
	// since we've started to load the keys.
	if(_keysNeedToBeReloaded) {
		_keysNeedToBeReloaded = NO;
		dispatch_async(_keyLoadingQueue, ^{
			[self _loadKeys:keys fetchSignatures:NO fetchUserAttributes:NO];
		});
	}
	
	// Inform all listeners that the keys were loaded.
	dispatch_async(dispatch_get_main_queue(), ^{
		NSArray *affectedKeys = [[[newKeysSet setByAddingObjectsFromSet:keys] valueForKey:@"description"] allObjects];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyManagerKeysDidChangeNotification object:[[self class] description] userInfo:[NSDictionary dictionaryWithObject:affectedKeys forKey:@"affectedKeys"]];
	});
}

- (void)fillKey:(GPGKey *)primaryKey withRange:(NSRange)lineRange {
	
	NSMutableArray *userIDs = nil, *subkeys = nil, *signatures = nil;
	GPGKey *key = nil;
	GPGUserID *userID = nil;
	GPGUserIDSignature *signature = nil;
	BOOL isPub = NO, isUid = NO, isRev = NO; // Used to differentiate pub/sub, uid/uat and sig/rev, because they are using the same if branch.
	NSUInteger uatIndex = 0;
	
	
	NSUInteger i = lineRange.location;
	NSUInteger end = i + lineRange.length;
	
	for (; i < end; i++) {
		NSArray *parts = [[_keyLines objectAtIndex:i] componentsSeparatedByString:@":"];
		NSString *type = [parts objectAtIndex:0];
		
		if (([type isEqualToString:@"pub"] && (isPub = YES)) || [type isEqualToString:@"sub"]) { // Primary-key or subkey.
			if (isPub) {
				key = primaryKey;
			} else {
				key = [[[GPGKey alloc] init] autorelease];
			}
			
			
			GPGValidity validity = [self validityForLetter:[parts objectAtIndex:1]];
			
			key.length = [[parts objectAtIndex:2] intValue];
			
			key.algorithm = [[parts objectAtIndex:3] intValue];
			
			key.keyID = [parts objectAtIndex:4];
			
			key.creationDate = [NSDate dateWithGPGString:[parts objectAtIndex:5]];
			
			NSDate *expirationDate = [NSDate dateWithGPGString:[parts objectAtIndex:6]];
			key.expirationDate = expirationDate;
			if (!(validity & GPGValidityExpired) && expirationDate && [[NSDate date] isGreaterThanOrEqualTo:expirationDate]) {
				validity |= GPGValidityExpired;
			}
			
			key.ownerTrust = [self validityForLetter:[parts objectAtIndex:8]];
			
			const char *capabilities = [[parts objectAtIndex:11] UTF8String];
			for (; *capabilities; capabilities++) {
				switch (*capabilities) {
					case 'd':
					case 'D':
						validity |= GPGValidityDisabled;
						break;
					case 'e':
						key.canEncrypt = YES;
					case 'E':
						key.canAnyEncrypt = YES;
						break;
					case 's':
						key.canSign = YES;
					case 'S':
						key.canAnySign = YES;
						break;
					case 'c':
						key.canCertify = YES;
					case 'C':
						key.canAnyCertify = YES;
						break;
					case 'a':
						key.canAuthenticate = YES;
					case 'A':
						key.canAnyAuthenticate = YES;
						break;
				}
			}
			
			key.validity = validity;
			
			if (isPub) {
				isPub = NO;
				
				userIDs = [[NSMutableArray alloc] init];
				subkeys = [[NSMutableArray alloc] init];
			} else {
				[subkeys addObject:key];
			}
			key.primaryKey = primaryKey;
			
		}
		else if (([type isEqualToString:@"uid"] && (isUid = YES)) || [type isEqualToString:@"uat"]) { // UserID or UAT (PhotoID).
			if (_fetchSignatures) {
				userID.signatures = signatures;
				signatures = [NSMutableArray array];
			}

			userID = [[[GPGUserID alloc] init] autorelease];
			userID.primaryKey = primaryKey;
			
			userID = [[[GPGUserID alloc] init] autorelease];
			userID.primaryKey = primaryKey;
			
			
			GPGValidity validity = [self validityForLetter:[parts objectAtIndex:1]];
			
			userID.creationDate = [NSDate dateWithGPGString:[parts objectAtIndex:5]];
			
			NSDate *expirationDate = [NSDate dateWithGPGString:[parts objectAtIndex:6]];
			userID.expirationDate = expirationDate;
			if (!(validity & GPGValidityExpired) && expirationDate && [[NSDate date] isGreaterThanOrEqualTo:expirationDate]) {
				validity |= GPGValidityExpired;
			}
			
			userID.hashID = [parts objectAtIndex:7];
			
			
			if (parts.count > 11 && [[parts objectAtIndex:11] rangeOfString:@"D"].length > 0) {
				validity |= GPGValidityDisabled;
			}
			
			userID.validity = validity;
			
			
			if (isUid) {
				isUid = NO;
				NSString *workText = [[parts objectAtIndex:9] unescapedString];
				userID.userIDDescription = workText;
				
				NSUInteger textLength = [workText length];
				NSRange range;
				
				if ([workText hasSuffix:@">"] && (range = [workText rangeOfString:@" <" options:NSBackwardsSearch]).length > 0) {
					range.location += 2;
					range.length = textLength - range.location - 1;
					userID.email = [workText substringWithRange:range];
					
					workText = [workText substringToIndex:range.location - 2];
					textLength -= (range.length + 3);
				}
				range = [workText rangeOfString:@" (" options:NSBackwardsSearch];
				if (range.length > 0 && range.location > 0 && [workText hasSuffix:@")"]) {
					range.location += 2;
					range.length = textLength - range.location - 1;
					userID.comment = [workText substringWithRange:range];
					
					workText = [workText substringToIndex:range.location - 2];
				}
				
				userID.name = workText;
				
			} else if (_fetchUserAttributes) { // Process attribute data.
				NSArray *infos = [_attributeInfos objectForKey:primaryKey.fingerprint];
				if (infos) {
					NSInteger index, count;
					
					do {
						NSDictionary *info = [infos objectAtIndex:uatIndex];
						uatIndex++;
						
						index = [[info objectForKey:@"index"] integerValue];
						count = [[info objectForKey:@"count"] integerValue];
						NSInteger location = [[info objectForKey:@"location"] integerValue];
						NSInteger length = [[info objectForKey:@"length"] integerValue];
						NSInteger uatType = [[info objectForKey:@"type"] integerValue];
						
						
						switch (uatType) {
							case 1: { // Image
								NSImage *image = [[NSImage alloc] initWithData:[_attributeData subdataWithRange:NSMakeRange(location + 16, length - 16)]];
								
								if (image) {
									NSImageRep *imageRep = [[image representations] objectAtIndex:0];
									NSSize size = imageRep.size;
									if (size.width != imageRep.pixelsWide || size.height != imageRep.pixelsHigh) { // Fix image size if needed.
										size.width = imageRep.pixelsWide;
										size.height = imageRep.pixelsHigh;
										imageRep.size = size;
										[image setSize:size];
									}
									
									userID.photo = image;
									[image release];
								}
								
								break;
							}
						}
						
					} while (index < count);
				}
				
				
			}
			
			[userIDs addObject:userID];
		}
		else if ([type isEqualToString:@"fpr"]) { // Fingerprint.
			NSString *fingerprint = [parts objectAtIndex:9];
			key.fingerprint = fingerprint;
			key.secret = [_secKeyFingerprints containsObject:fingerprint];
			
		}
		else if ([type isEqualToString:@"sig"] || ([type isEqualToString:@"rev"] && (isRev = YES))) { // Signature.
			signature = [[[GPGUserIDSignature alloc] init] autorelease];
			
			
			signature.revocation = isRev;
			
			signature.algorithm = [[parts objectAtIndex:3] intValue];
			
			signature.keyID = [parts objectAtIndex:4];
			
			signature.creationDate = [NSDate dateWithGPGString:[parts objectAtIndex:5]];
			
			signature.expirationDate = [NSDate dateWithGPGString:[parts objectAtIndex:6]];
			
			NSString *field = [parts objectAtIndex:10];
			signature.signatureClass = hexToByte([field UTF8String]);
			signature.local = [field hasSuffix:@"l"];
			
			
			[signatures addObject:signature];
			
			isRev = NO;
		}
		else if ([type isEqualToString:@"spk"]) { // Signature subpacket. Needed for the revocation reason.
			switch ([[parts objectAtIndex:1] integerValue]) {
				case 29:
					signature.reason = [[parts objectAtIndex:4] unescapedString];
					break;
			}
		}
		
	}

	if (_fetchSignatures) {
		userID.signatures = signatures;
	}
	
	primaryKey.userIDs = userIDs;
	primaryKey.subkeys = subkeys;
	
	[userIDs release];
	[subkeys release];
}






- (NSDictionary *)keysByKeyID {
	dispatch_once(&_once_keysByKeyID, ^{
		NSMutableDictionary *keysByKeyID = [[NSMutableDictionary alloc] init];
		for (GPGKey *key in self->_mutableAllKeys) {
			[keysByKeyID setObject:key forKey:key.keyID];
			for (GPGKey *subkey in key.subkeys) {
				[keysByKeyID setObject:subkey forKey:subkey.keyID];
			}
		}
		
		self.keysByKeyID = keysByKeyID;
		[keysByKeyID release];
	});
	
	return [[_keysByKeyID retain] autorelease];
}

- (NSSet *)allKeys {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if(!_allKeys)
			[self loadAllKeys];
	});
	
	return [[_allKeys retain] autorelease];
}

- (void)rebuildKeysCache {
	NSMutableSet *publicKeys = nil;
	NSMutableSet *secretKeys = nil;
	
	[_allKeys enumerateObjectsUsingBlock:^(GPGKey *key, BOOL *stop) {
		if(key.secret)
			[secretKeys addObject:key];
		else
			[publicKeys addObject:key];
	}];
	
	NSSet *oldPublicKeys = _publicKeys;
	_publicKeys = [publicKeys copy];
	[oldPublicKeys release];
	
	NSSet *oldSecretKeys = _secretKeys;
	_secretKeys = [secretKeys copy];
	[oldSecretKeys release];
}

- (NSSet *)publicKeys {
	// Make sure all keys are actually loaded.
	[self allKeys];
	
	return [[_publicKeys retain] autorelease];
}

- (NSSet *)secretKeys {
	// Make sure all keys are actually loaded.
	[self allKeys];
	
	return [[_secretKeys retain] autorelease];
}

- (void)setCompletionQueue:(dispatch_queue_t)completionQueue {
	NSAssert(completionQueue != nil, @"nil or NULL is not allowed for completionQueue");
	if(completionQueue == _completionQueue)
		return;
	
	if(_completionQueue) {
		dispatch_release(_completionQueue);
		_completionQueue = NULL;
	}
	if(completionQueue) {
		dispatch_retain(completionQueue);
		_completionQueue = completionQueue;
	}
	
}

#pragma mark Helper methods

- (GPGValidity)validityForLetter:(NSString *)letter {
	if ([letter length] == 0) {
		return GPGValidityUnknown;
	}
	switch ([letter characterAtIndex:0]) {
		case 'q':
			return GPGValidityUndefined;
		case 'n':
			return GPGValidityNever;
		case 'm':
			return GPGValidityMarginal;
		case 'f':
			return GPGValidityFull;
		case 'u':
			return GPGValidityUltimate;
		case 'i':
			return GPGValidityInvalid;
		case 'r':
			return GPGValidityRevoked;
		case 'e':
			return GPGValidityExpired;
		case 'd':
			return GPGValidityDisabled;
	}
	return GPGValidityUnknown;
}

- (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing {
	NSRange searchRange, findRange;
	NSUInteger textLength = [colonListing length];
	NSMutableSet *fingerprints = [NSMutableSet setWithCapacity:3];
	NSString *lineText;
	
	searchRange.location = 0;
	searchRange.length = textLength;
	
	
	while ((findRange = [colonListing rangeOfString:@"\nfpr:" options:NSLiteralSearch range:searchRange]).length > 0) {
		findRange.location++;
		lineText = [colonListing substringWithRange:[colonListing lineRangeForRange:findRange]];
		[fingerprints addObject:[[lineText componentsSeparatedByString:@":"] objectAtIndex:9]];
		
		searchRange.location = findRange.location + findRange.length;
		searchRange.length = textLength - searchRange.location;
	}
	
	return fingerprints;
}

- (void)_loadExtrasForKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchAttributes:(BOOL)fetchAttributes completionHandler:(void(^)(NSSet *))completionHandler {
	// Keys might be either a list of real keys or fingerprints.
	// In any way, only the fingerprints are of interest for us, since
	// they'll be used to load the appropriate keys.
	__block GPGKeyManager *weakSelf = self;
	
	NSSet *keysCopy = [keys copy];
	NSSet *fingerprints = [keysCopy valueForKey:@"description"];
	[keysCopy release];
	
	dispatch_async(_keyLoadingQueue, ^{
		[weakSelf _loadKeys:fingerprints fetchSignatures:fetchSignatures fetchUserAttributes:fetchAttributes];
		
		// Signatures should be available for the keys. Now let's get them via their
		// fingerprint.
		NSSet *keysWithSignatures = [weakSelf->_allKeys objectsPassingTest:^BOOL(GPGKey *key, BOOL *stop) {
			if([fingerprints containsObject:[key description]])
				return YES;
			return NO;
		}];
		
		if(completionHandler) {
			dispatch_async(self.completionQueue != NULL ? self.completionQueue : dispatch_get_main_queue(), ^{
				completionHandler(keysWithSignatures);
			});
		}
	});
}

- (void)loadSignaturesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:YES fetchAttributes:NO completionHandler:completionHandler];
}

- (void)loadAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:NO fetchAttributes:YES completionHandler:completionHandler];
}

- (void)loadSignaturesAndAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler {
	[self _loadExtrasForKeys:keys fetchSignatures:YES fetchAttributes:YES completionHandler:completionHandler];
}

#pragma mark Delegate

- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt {
	
	switch (status) {
		case GPG_STATUS_ATTRIBUTE: {
			NSArray *parts = [prompt componentsSeparatedByString:@" "];
			NSString *fingerprint = [parts objectAtIndex:0];
			NSInteger length = [[parts objectAtIndex:1] integerValue];
			NSString *type = [parts objectAtIndex:2];
			NSString *index = [parts objectAtIndex:3];
			NSString *count = [parts objectAtIndex:4];

			
			NSNumber *location = [NSNumber numberWithUnsignedInteger:_attributeDataLocation];
			_attributeDataLocation += length;
			
			NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
								  @"length", [NSNumber numberWithInteger:length],
								  @"type", type,
								  @"location", location,
								  @"index", index,
								  @"count", count,
								  nil];
			
			NSMutableArray *infos = [_attributeInfos objectForKey:fingerprint];
			if (!infos) {
				infos = [[NSMutableArray alloc] init];
				[_attributeInfos setObject:infos forKey:fingerprint];
				[infos release];
			}
			
			[infos addObject:info];
			
			break;
		}
			
	}
	return nil;
}

#pragma mark Keyring modifications notification handler

- (void)keysDidChange:(NSNotification *)notification {
	if([_keyLoadingCheckLock tryLock]) {
		//NSLog(@"[%@]: Succeeded acquiring notification execute lock.", [NSThread currentThread]);
		// If notification doesn't contain any keys, all keys have
		// to be rebuild.
		// If only a few keys were modified, the notification info will contain
		// the affected keys, and only these have to be rebuilt.
		//NSLog(@"[%@]: Keys did change - will reload keys", [NSThread currentThread]);
		
		// Call load keys.
		[self loadAllKeys];
		// At this point, it's ok for new notifications to queue key loads.
		[_keyLoadingCheckLock unlock];
	}
	else {
		//NSLog(@"[%@]: Failed to acquire notification execute lock.", [NSThread currentThread]);
		_keysNeedToBeReloaded = YES;
	}
}

#pragma mark Singleton

+ (GPGKeyManager *)sharedInstance {
	static dispatch_once_t onceToken;
    static GPGKeyManager *sharedInstance;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:nil] realInit];
    });
    
    return sharedInstance;
}

- (id)realInit {
	if (!(self = [super init])) {
		return nil;
	}
	
	_mutableAllKeys = [[NSMutableSet alloc] init];
	_keyLoadingQueue = dispatch_queue_create("org.gpgtools.libmacgpg.GPGKeyManager.key-loader", NULL);
	// Start listening to keyring modifications notifcations.
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeysChangedNotification object:nil];
	_keysNeedToBeReloaded = NO;
	_keyLoadingCheckLock = [[NSLock alloc] init];
	_completionQueue = NULL;
	
	return self;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];
}

- (id)init {
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

- (oneway void)release {
}

- (id)autorelease {
    return self;
}



@end
