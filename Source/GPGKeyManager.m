
#import "GPGKeyManager.h"
#import "GPGTypesRW.h"
#import "GPGWatcher.h"
#import "GPGTask.h"

NSString * const GPGKeyManagerKeysDidChangeNotification = @"GPGKeyManagerKeysDidChangeNotification";

@interface GPGKeyManager () <GPGTaskDelegate>

@property (copy, readwrite) NSDictionary *keysByKeyID;
@property (copy, readwrite) NSSet *secretKeys;

@end

@implementation GPGKeyManager

@synthesize allKeys=_allKeys, keysByKeyID=_keysByKeyID,
			secretKeys=_secretKeys, completionQueue=_completionQueue,
			allowWeakDigestAlgos=_allowWeakDigestAlgos,
			homedir=_homedir;

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
		
		_fetchSignatures = fetchSignatures;
		_fetchUserAttributes = fetchUserAttributes;
		
		// 1. Fetch all secret keys.
		@try {
			// Get all fingerprints of the secret keys.
			GPGTask *gpgTask = [GPGTask gpgTask];
			gpgTask.nonBlocking = YES;
			if (_homedir) {
				[gpgTask addArgument:@"--homedir"];
				[gpgTask addArgument:_homedir];
			}
			gpgTask.batchMode = YES;
			if (self.allowWeakDigestAlgos) {
				[gpgTask addArgument:@"--allow-weak-digest-algos"];
			}
			[gpgTask addArgument:@"--list-secret-keys"];
			[gpgTask addArgument:@"--with-fingerprint"];
			[gpgTask addArgument:@"--with-fingerprint"];
			[gpgTask addArguments:keyArguments];
				
			[gpgTask start];
				
			self->_secKeyInfos = [[self parseSecColonListing:gpgTask.outData.gpgLines] retain];
        }
		@catch (NSException *exception) {
			//TODO: Set error code.
			GPGDebugLog(@"Unable to load secret keys.")
		}
		
		// Get the infos from gpg.
		GPGTask *gpgTask = [GPGTask gpgTask];
		gpgTask.nonBlocking = YES;
		if (_homedir) {
			[gpgTask addArgument:@"--homedir"];
			[gpgTask addArgument:_homedir];
		}
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
			gpgTask.delegate = self;
		}
		if (self.allowWeakDigestAlgos) {
			[gpgTask addArgument:@"--allow-weak-digest-algos"];
		}
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:keyArguments];
		
		// TODO: We might have to retain this task, since it might be used in a delegate.
		[gpgTask start];
		
		// ======= Parsing =======

		_attributeData = [gpgTask.attributeData retain]; //attributeData is only needed for UATs (PhotoID).
		_keyLines = gpgTask.outData.gpgLines;

		dispatch_queue_t dispatchQueue = NULL;
		if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
			dispatchQueue = dispatch_queue_create("org.gpgtools.libmacgpg._loadKeys.gpgTask", DISPATCH_QUEUE_CONCURRENT);
		else {
			dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_retain(dispatchQueue);
		}
		dispatch_group_t dispatchGroup = dispatch_group_create();

		NSMutableArray *newKeys = [[NSMutableArray alloc] init];
		
		// Loop thru all lines. Starting with the last line.
		NSUInteger lastLine = _keyLines.count;
		NSInteger index = lastLine - 1;
		for (; index >= 0; index--) {
			NSString *line = [_keyLines objectAtIndex:index];
			if ([line hasPrefix:@"pub"]) {
				GPGKey *key = [[GPGKey alloc] init];
				[newKeys addObject:key];
				[key release];
				
				@autoreleasepool {
					[self fillKey:key withRange:NSMakeRange(index, lastLine - index)];
				}

				lastLine = index;
			}
		}
		
		dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
        dispatch_release(dispatchGroup);
        dispatch_release(dispatchQueue);
		
		[_attributeData release];
		[_attributeInfos release];
		_attributeInfos = nil;
		
		newKeysSet = [NSSet setWithArray:newKeys];
		[newKeys release];
		
		if (keys) {
			[_mutableAllKeys minusSet:keys];
			[_mutableAllKeys minusSet:newKeysSet];
		} else {
			[_mutableAllKeys removeAllObjects];
		}
		[_mutableAllKeys unionSet:newKeysSet];
		
		
		
		
		NSMutableDictionary *keysByKeyID = [[NSMutableDictionary alloc] init];
		NSMutableSet *secretKeys = [[NSMutableSet alloc] init];
		
		for (GPGKey *key in _mutableAllKeys) {
			if (key.secret) {
				[secretKeys addObject:key];
			}
			[keysByKeyID setObject:key forKey:key.keyID];
			for (GPGKey *subkey in key.subkeys) {
				[keysByKeyID setObject:subkey forKey:subkey.keyID];
			}
		}
		
		self.secretKeys = secretKeys;
		[secretKeys release];
		
		self.keysByKeyID = keysByKeyID;
		if (fetchSignatures) {
			for (GPGKey *key in _mutableAllKeys) {
				for (GPGUserID *uid in key.userIDs) {
					for (GPGUserIDSignature *sig in uid.signatures) {
						sig.primaryKey = [keysByKeyID objectForKey:sig.keyID]; // Set the key used to create the signature.
					}
				}
			}
		}
		[keysByKeyID release];

				
	}
	@catch (NSException *exception) {
		//TODO: Detect unavailable keyring.
		
		GPGDebugLog(@"loadKeys failed: %@", exception);
		_mutableAllKeys = nil;
#ifdef DEBUGGING
		if ([exception respondsToSelector:@selector(errorCode)] && [(GPGException *)exception errorCode] != GPGErrorNotFound) {
			@throw exception;
		}
#endif
	}
	@finally {
		[_secKeyInfos release];
		_secKeyInfos = nil;
		
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
		NSDictionary *userInfo = nil;
		if (affectedKeys) {
			userInfo = [NSDictionary dictionaryWithObject:affectedKeys forKey:@"affectedKeys"];
		}
		
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeyManagerKeysDidChangeNotification object:[[self class] description] userInfo:userInfo];
	});

	// Start the key ring watcher.
	[self startKeyringWatcher];
}

- (void)fillKey:(GPGKey *)primaryKey withRange:(NSRange)lineRange {
	
	NSMutableArray *userIDs = nil, *subkeys = nil, *signatures = nil;
	GPGKey *key = nil;
	GPGKey *signedObject = nil; // A GPGUserID or GPGKey.
	
	GPGUserIDSignature *signature = nil;
	BOOL isPub = NO, isUid = NO, isRev = NO; // Used to differentiate pub/sub, uid/uat and sig/rev, because they are using the same if branch.
	NSUInteger uatIndex = 0;
	
	
	NSUInteger i = lineRange.location;
	NSUInteger end = i + lineRange.length;
	
	for (; i < end; i++) {
		NSArray *parts = [[_keyLines objectAtIndex:i] componentsSeparatedByString:@":"];
		NSString *type = [parts objectAtIndex:0];
		
		if (([type isEqualToString:@"pub"] && (isPub = YES)) || [type isEqualToString:@"sub"]) { // Primary-key or subkey.
			if (_fetchSignatures) {
				signedObject.signatures = signatures;
				signatures = [NSMutableArray array];
			}
			if (isPub) {
				key = primaryKey;
			} else {
				key = [[[GPGKey alloc] init] autorelease];
			}
			signedObject = key;
			
			
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
				signedObject.signatures = signatures;
				signatures = [NSMutableArray array];
			}

			GPGUserID *userID = [[[GPGUserID alloc] init] autorelease];
			userID.primaryKey = primaryKey;
			signedObject = (GPGKey *)userID; // signedObject is a GPGKey or GPGUserID. It's only casted to allow "signedObject.signatures = signatures".
			
			
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
				NSDictionary *dict = [[[parts objectAtIndex:9] unescapedString] splittedUserIDDescription];
				userID.userIDDescription = [dict objectForKey:@"userIDDescription"];
				userID.name = [dict objectForKey:@"name"];
				userID.email = [dict objectForKey:@"email"];
				userID.comment = [dict objectForKey:@"comment"];

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
									
									userID.image = image;
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
			if ([fingerprint isEqualToString:@"00000000000000000000000000000000"]) {
				fingerprint = primaryKey.keyID;
			}
			
			key.fingerprint = fingerprint;
			
			NSDictionary *secKeyInfo = [_secKeyInfos objectForKey:fingerprint];
			if (secKeyInfo) {
				key.secret = YES;
				NSString *cardID = [secKeyInfo objectForKey:@"cardID"];
				key.cardID = cardID;
			}
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
			
			if (parts.count > 15) {
				signature.hashAlgorithm = [[parts objectAtIndex:15] intValue];
			}
			
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

	if (_fetchSignatures && signatures) {
		signedObject.signatures = signatures;
	}
	
	primaryKey.userIDs = userIDs;
	primaryKey.subkeys = subkeys;
	
	[userIDs release];
	[subkeys release];
}

- (void)startKeyringWatcher {
    // The keyring watcher is only to be started after all the keys have
    // been loaded at least once.
    // In order to make sure of that, this method is always called after loadAllKeys
    // has completed, but using dispatch_once we'll also make sure that it's only started
    // once.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [GPGWatcher activate];
    });
}

- (NSDictionary *)keysByKeyID {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if(!_keysByKeyID)
			[self loadAllKeys];
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

- (NSSet *)allKeysAndSubkeys {
	/* TODO: Must be declared __weak once ARC! */
	static id oldAllKeys = (id)1;
	
	dispatch_semaphore_wait(_allKeysAndSubkeysOnce, DISPATCH_TIME_FOREVER);
	
	NSSet *allKeys = self.allKeys;
	
	if (oldAllKeys != allKeys) {
		oldAllKeys = allKeys;
		
		NSMutableSet *allKeysAndSubkeys = [[NSMutableSet alloc] initWithSet:allKeys copyItems:NO];
		
		for (GPGKey *key in allKeys) {
			[allKeysAndSubkeys addObjectsFromArray:key.subkeys];
		}
		
		id old = _allKeysAndSubkeys;
		_allKeysAndSubkeys = [allKeysAndSubkeys copy];
		[old release];
		[allKeysAndSubkeys release];
	}
	
	dispatch_semaphore_signal(_allKeysAndSubkeysOnce);

	return [[_allKeysAndSubkeys retain] autorelease];
}

- (NSSet *)secretKeys {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (!_secretKeys) {
			[self loadAllKeys];
		}
	});
	
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



- (NSDictionary *)parseSecColonListing:(NSArray *)lines {
	NSMutableDictionary *infos = [NSMutableDictionary dictionary];
	NSUInteger count = lines.count;
	
	NSDictionary *keyInfo = @{};
	
	
	for (NSInteger i = 0; i < count; i++) { // Loop backwards through the lines.
		NSArray *parts = [[lines objectAtIndex:i] componentsSeparatedByString:@":"];
		NSString *type = [parts objectAtIndex:0];
		
		if ([type isEqualToString:@"sec"] || [type isEqualToString:@"ssb"]) {
			NSString *cardID = [parts objectAtIndex:14];
			if (cardID.length > 0) {
				keyInfo = @{@"cardID":cardID};
			} else {
				keyInfo = @{};
			}
		} else if ([type isEqualToString:@"fpr"]) {
			NSString *fingerprint = [parts objectAtIndex:9];
			[infos setObject:keyInfo forKey:fingerprint];
		}
	}
	
	return infos;
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
								  [NSNumber numberWithInteger:length], @"length",
								  type, @"type",
								  location, @"location",
								  index, @"index", 
								  count, @"count", 
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
	// We're on the main queue, so we should immediately dispatch
	// off. Reloading keys could take longer.
	dispatch_async(_keyChangeNotificationQueue, ^{
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
	});
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
	_keyChangeNotificationQueue = dispatch_queue_create("org.gpgtools.libmacgpg.GPGKeyManager.key-change", NULL);
	// Start listening to keyring modifications notifcations.
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysDidChange:) name:GPGKeysChangedNotification object:nil];
	_keysNeedToBeReloaded = NO;
	_keyLoadingCheckLock = [[NSLock alloc] init];
	_completionQueue = NULL;
	
	_allKeysAndSubkeysOnce = dispatch_semaphore_create(1);

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
