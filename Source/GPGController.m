#import "GPGController.h"
#import "GPGKey.h"
#import "GPGException.h"
#import "GPGTaskOrder.h"
#import "GPGRemoteKey.h"
#import "GPGSignature.h"


//TODO: Handle exception!


@interface GPGController ()
@property (retain) GPGSignature *lastSignature;
- (void)updateKeysWithDict:(NSDictionary *)aDict;
- (void)addArgumentsForKeyserver;
- (void)addArgumentsForSignerKeys;
- (void)addArgumentsForComments;
- (void)addArgumentsForOptions;
- (void)handleException:(NSException *)e;
- (void)operationDidFinishWithReturnValue:(id)value;
@end


@implementation GPGController
@synthesize delegate;
@synthesize keyserver;
@synthesize async;
@synthesize userInfo;
@synthesize useArmor;
@synthesize useTextMode;
@synthesize printVersion;
@synthesize useDefaultComments;
@synthesize trustAllKeys;
@synthesize signatures;
@synthesize lastSignature;


- (NSArray *)comments {
	return [[comments copy] autorelease];
}
- (NSArray *)signerKeys {
	return [[signerKeys copy] autorelease];
}
- (void)addComment:(NSString *)comment {
	[self willChangeValueForKey:@"comments"];
	[comments addObject:comment];
	[self didChangeValueForKey:@"comments"];
}
- (void)removeCommentAtIndex:(NSUInteger)index {
	[self willChangeValueForKey:@"comments"];
	[comments removeObjectAtIndex:index];
	[self didChangeValueForKey:@"comments"];
}
- (void)addSignerKey:(NSString *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys addObject:signerKey];
	[self didChangeValueForKey:@"signerKeys"];
}
- (void)removeSignerKeyAtIndex:(NSUInteger)index {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeObjectAtIndex:index];
	[self didChangeValueForKey:@"signerKeys"];
}



#pragma mark Init

- (id)init {
	if (self = [super init]) {
		comments = [[NSMutableArray alloc] init];
		signerKeys = [[NSMutableArray alloc] init];
		signatures = [[NSMutableArray alloc] init];
		asyncProxy = [AsyncProxy alloc];
		[asyncProxy setRealObject:self];
	}
	return self;
}



- (void)stop {
	if (gpgTask.isRunning) {
		[gpgTask stop];
	}
}



#pragma mark Search and update keys

- (NSSet *)allKeys {
	return [self updateKeys:nil searchFor:nil withSigs:NO];
}
- (NSSet *)keysForSearchPattern:(NSString *)searchPattern {
	return [self updateKeys:nil searchFor:[NSSet setWithObject:searchPattern] withSigs:NO];
}
- (NSSet *)keysForSearchPatterns:(id <EnumerationList>)searchPatterns {
	return [self updateKeys:nil searchFor:searchPatterns withSigs:NO];
}

- (NSSet *)updateKeys:(id <EnumerationList>)keyList {
	return [self updateKeys:keyList searchFor:keyList withSigs:[keyList count] < 5];
}
- (NSSet *)updateKeys:(id <EnumerationList>)keyList withSigs:(BOOL)withSigs {
	return [self updateKeys:keyList searchFor:keyList withSigs:withSigs];
}
- (NSSet *)updateKeys:(id <EnumerationList>)keyList searchFor:(id <EnumerationList>)serachList withSigs:(BOOL)withSigs {
	NSString *pubColonListing, *secColonListing;
	NSSet *secKeyFingerprints, *updatedKeys;
	NSArray *fingerprints, *listings;
	
	if (!keyList) {
		keyList = [NSSet set];
	}
	if (!serachList) {
		serachList = [NSSet set];
	}
	
	
	NSArray *searchStrings = nil;
	if ([serachList count] > 0) {
		NSMutableSet *searchSet = [NSMutableSet setWithCapacity:[serachList count]];
		
		for (id item in serachList) {
			[searchSet addObject:[item description]];
		}
		searchStrings = [searchSet allObjects];
	}
	
	
	gpgTask = [GPGTask gpgTask];
	if (withSigs) {
		[gpgTask addArgument:@"--list-sigs"];
		[gpgTask addArgument:@"--list-options"];
		[gpgTask addArgument:@"show-sig-subpackets=29"];
	} else {
		[gpgTask addArgument:@"--list-keys"];
	}

	[gpgTask addArgument:withSigs ? @"--list-sigs" : @"--list-keys"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArguments:searchStrings];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"List public keys failed!" gpgTask:gpgTask];
	}
	pubColonListing = gpgTask.outText;
	
	
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--list-secret-keys"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArguments:searchStrings];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"List secret keys failed!" gpgTask:gpgTask];
	}
	secColonListing = gpgTask.outText;
	
	
	[[self class] colonListing:pubColonListing toArray:&listings andFingerprints:&fingerprints];
	secKeyFingerprints = [[self class] fingerprintsFromColonListing:secColonListing];
	
	
	
	NSDictionary *argumentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										listings, @"listings", 
										fingerprints, @"fingerprints", 
										secKeyFingerprints, @"secKeyFingerprints", 
										keyList, @"keysToUpdate",
										[NSValue valueWithPointer:&updatedKeys], @"updatedKeys",
										[NSNumber numberWithBool:withSigs], @"withSigs", nil];
	
	[self performSelectorOnMainThread:@selector(updateKeysWithDict:) withObject:argumentDictionary waitUntilDone:YES];
	
	
	
	return updatedKeys;
}


#pragma mark Encrypt, decrypt, sign and verify



- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(id <EnumerationList>)recipients hiddenRecipients:(id <EnumerationList>)hiddenRecipients {
	@try {
		if (async && !asyncStarted) {
			asyncStarted = YES;
			[asyncProxy processData:data withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
			return nil;
		}
		asyncStarted = NO;
		
		
		if (mode & (GPGEncryptFlags | GPGSignFlags) == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Unknwon mode: %i!", mode];
		}
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addInData:data];
		
		
		[self addArgumentsForOptions];
		[self addArgumentsForComments];
		[self addArgumentsForSignerKeys];
		
		
		
		if (mode & GPGPublicKeyEncrypt) {
			[gpgTask addArgument:@"--encrypt"];
			if ([recipients count] + [hiddenRecipients count] == 0) {
				[NSException raise:NSInvalidArgumentException format:@"No recipient specified!"];
			}
			for (NSString *recipient in recipients) {
				[gpgTask addArgument:@"--recipient"];
				[gpgTask addArgument:[recipient description]];		
			}
			for (NSString *recipient in hiddenRecipients) {
				[gpgTask addArgument:@"--hidden-recipient"];
				[gpgTask addArgument:[recipient description]];		
			}
		}
		if (mode & GPGSymetricEncrypt) {
			[gpgTask addArgument:@"--symmetric"];
		}
		
		
		switch (mode & GPGSignFlags) {
			case GPGSign:
				[gpgTask addArgument:@"--sign"];			
				break;
			case GPGClearSign:
				[gpgTask addArgument:@"--clearsign"];			
				break;
			case GPGDetachedSign:
				[gpgTask addArgument:@"--detach-sign"];			
				break;
			case 0:
				break;
			default:			
				[NSException raise:NSInvalidArgumentException format:@"Unknown sign mode: %i!", mode && GPGSignFlags];
				break;
		}
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Process data failed!" gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	}
	
	NSData *retVal = gpgTask.outData;
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (NSData *)decryptData:(NSData *)data {
	@try {
		if (async && !asyncStarted) {
			asyncStarted = YES;
			[asyncProxy decryptData:data];
			return nil;
		}
		asyncStarted = NO;

		
		gpgTask = [GPGTask gpgTask];
		gpgTask.delegate = self;
		[gpgTask addInData:data];
		
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--decrypt"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Decrypt failed!" gpgTask:gpgTask];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	}
	
	NSData *retVal = gpgTask.outData;
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData {
	@try {
		if (async && !asyncStarted) {
			asyncStarted = YES;
			[asyncProxy verifySignature:signatureData originalData:originalData];
			return nil;
		}
		asyncStarted = NO;
		
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.delegate = self;
		[gpgTask addInData:signatureData];
		[gpgTask addInData:originalData];
		
		
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--verify"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Verify failed!" gpgTask:gpgTask];
		}
	
	} @catch (NSException *e) {
		[self handleException:e];
	}
	
	NSArray *retVal = self.signatures;
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}





#pragma mark Edit keys

- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(NSInteger)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(NSInteger)subkeyLength 
				  daysToExpire:(NSInteger)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase {
		
	
	NSMutableString *cmdText = [NSMutableString string];
	
	
	
	[cmdText appendFormat:@"Key-Type: %i\n", keyType];
	[cmdText appendFormat:@"Key-Length: %i\n", keyLength];
	
	if (subkeyType) {
		[cmdText appendFormat:@"Subkey-Type: %i\n", subkeyType];
		[cmdText appendFormat:@"Subkey-Length: %i\n", subkeyLength];
	}
	
	[cmdText appendFormat:@"Name-Real: %@\n", name];
	[cmdText appendFormat:@"Name-Email: %@\n", email];
	if ([comment length] > 0) {
		[cmdText appendFormat:@"Name-Comment: %@\n", comment];
	}
	
	[cmdText appendFormat:@"Expire-Date: %i\n", daysToExpire];
	
	if (preferences) {
		[cmdText appendFormat:@"Preferences: %@\n", preferences];
	}
	
	if (passphrase) {
		if (![passphrase isEqualToString:@""]) {
			[cmdText appendFormat:@"Passphrase: %@\n", passphrase];
		}
		[cmdText appendString:@"%no-ask-passphrase\n"];
	} else {
		[cmdText appendString:@"%ask-passphrase\n"];
	}
	
	[cmdText appendString:@"%commit\n"];
	
	
	
	gpgTask = [GPGTask gpgTaskWithArgument:@"--gen-key"];
	gpgTask.batchMode = YES;
	gpgTask.delegate = self;
	[gpgTask addInText:cmdText];

	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Generate new key failed!" gpgTask:gpgTask];
	}
}

- (void)deleteKeys:(id <EnumerationList>)keys withMode:(GPGDeleteKeyMode)mode {
	if ([keys count] == 0) {
		[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
	}
	gpgTask = [GPGTask gpgTask];

	switch (mode) {
		case GPGDeleteSecretKey:
			[gpgTask addArgument:@"--delete-secret-keys"];
			break;
		case GPGDeletePublicAndSecretKey:
			[gpgTask addArgument:@"--delete-secret-and-public-key"];
			break;
		case GPGDeletePublicKey:
			[gpgTask addArgument:@"--delete-keys"];
			break;
		default:
			[NSException raise:NSInvalidArgumentException format:@"Unknown GPGDeleteKeyMode: %i", mode];
	}
	for (id key in keys) {
		[gpgTask addArgument:[key description]];
	}

	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Set primary userID failed!" gpgTask:gpgTask];
	}
}

- (void)cleanKey:(id <KeyFingerprint>)key {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:@"clean"];
	[gpgTask addArgument:@"save"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Clean failed!" gpgTask:gpgTask];
	}
}

- (void)minimizeKey:(id <KeyFingerprint>)key {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:@"minimize"];
	[gpgTask addArgument:@"save"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Minimize failed!" gpgTask:gpgTask];
	}
}

- (NSData *)genRevokeCertificateForKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
	if (description) {
		NSArray *lines = [description componentsSeparatedByString:@"\n"];
		for (NSString *line in lines) {
			[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
		}
	}
	[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"-a"];
	[gpgTask addArgument:@"--gen-revoke"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Generate revoke certificate failed!" gpgTask:gpgTask];
	}
	
	return gpgTask.outData;
}

- (void)setExpirationDateForSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key daysToExpire:(NSInteger)daysToExpire {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	
	if (subkey) {
		int index = [self indexOfSubkey:subkey fromKey:key];
		if (index > 0) {
			[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
		} else {
			@throw [GPGException exceptionWithName:@"GPGException" reason:@"Subkey not found!" userInfo:
					[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]];
		}
	}
	
	[order addCmd:@"expire\n" prompt:@"keyedit.prompt"];
	[order addInt:daysToExpire prompt:@"keygen.valid"];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Add userID failed!" gpgTask:gpgTask];
	}
}

- (void)changePassphraseForKey:(id <KeyFingerprint>)key {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addCmd:@"passwd\n" prompt:@"keyedit.prompt"];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Change passphrase failed!" gpgTask:gpgTask];
	}
}

- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	
	if (hashID) {
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid <= 0) {
			@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
					[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]];
		}
		[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
	}
	[order addCmd:[NSString stringWithFormat:@"setpref %@\n", preferences] prompt:@"keyedit.prompt"];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Set preferences failed!" gpgTask:gpgTask];
	}
}

- (void)key:(id <KeyFingerprint>)key setDisabled:(BOOL)disabled {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:disabled ? @"disable" : @"enable"];
	[gpgTask addArgument:@"quit"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:disabled ? @"Disable key failed!" : @"Enable key failed!" gpgTask:gpgTask];
	}
}

- (void)key:(id <KeyFingerprint>)key setOwnerTrsut:(GPGValidity)trust {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addCmd:@"trust\n" prompt:@"keyedit.prompt"];
	[order addInt:trust prompt:@"edit_ownertrust.value"];
	[order addCmd:@"quit\n" prompt:@"keyedit.prompt"];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];

	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Set trust failed!" gpgTask:gpgTask];
	}
}


#pragma mark Import and export

- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addInData:data];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"--import"];
	if (fullImport) {
		[gpgTask addArgument:@"--import-options"];
		[gpgTask addArgument:@"import-local-sigs"];
		[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
	}
	
	
	[gpgTask start];
	
	NSString *statusText = gpgTask.statusText;
	//TODO: Better error detection!
	if ([statusText rangeOfString:@"[GNUPG:] IMPORT_OK "].length <= 0) {
		@throw [GPGException exceptionWithReason:@"Import failed!" gpgTask:gpgTask];
	}
	
	return statusText;
}

- (NSData *)exportKeys:(id <EnumerationList>)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
	[arguments addObject:@"--export"];
	
	if (fullExport) {
		[arguments addObject:@"--export-options"];
		[arguments addObject:@"export-local-sigs,export-sensitive-revkeys"];
	}
	for (id <KeyFingerprint> key in keys) {
		[arguments addObject:[key description]];
	}
	
	
	gpgTask = [GPGTask gpgTaskWithArguments:arguments];
	[self addArgumentsForOptions];
	[self addArgumentsForComments];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Export failed!" gpgTask:gpgTask];
	}
	NSData *exportedData = gpgTask.outData;
	
	
	if (allowSec) {
		[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
		gpgTask = [GPGTask gpgTaskWithArguments:arguments];
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Export failed!" gpgTask:gpgTask];
		}
		exportedData = [NSMutableData dataWithData:exportedData];
		[(NSMutableData *)exportedData appendData:gpgTask.outData];
	}
	
	return exportedData;
}


#pragma mark Working with Signatures

- (void)signUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key signKey:(id <KeyFingerprint>)signKey type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	NSString *uid;
	if (!hashID) {
		uid = @"uid *\n";
	} else {
		int uidIndex = [self indexOfUserID:hashID fromKey:key];
		if (uidIndex > 0) {
			uid = [NSString stringWithFormat:@"uid %i\n", uidIndex];
		} else {
			@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
					[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]];
		}
	}

	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addCmd:uid prompt:@"keyedit.prompt"];
	[order addCmd:local ? @"lsign\n" : @"sign\n" prompt:@"keyedit.prompt"];
	[order addCmd:[NSString stringWithFormat:@"%i\n", daysToExpire] prompt:@"siggen.valid" optional:YES];
	[order addCmd:[NSString stringWithFormat:@"%i\n", type] prompt:@"sign_uid.class" optional:YES];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];

	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	if (signKey) {
		[gpgTask addArgument:@"-u"];
		[gpgTask addArgument:[signKey description]];
	}
	[gpgTask addArgument:@"--ask-cert-expire"];
	[gpgTask addArgument:@"--ask-cert-level"];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Sign userID failed!" gpgTask:gpgTask];
	}
}

- (void)revokeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	NSInteger uid = [self indexOfUserID:userID.hashID fromKey:key];
	
	if (uid > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		[order addCmd:@"revsig\n" prompt:@"keyedit.prompt"];
		
		NSArray *userIDsignatures = userID.signatures;
		for (GPGKeySignature *aSignature in userIDsignatures) {
			if (aSignature == signature) {
				[order addCmd:@"y\n" prompt:@"ask_revoke_sig.one"];
			} else {
				[order addCmd:@"n\n" prompt:@"ask_revoke_sig.one"];
			}
		}
		[order addCmd:@"y\n" prompt:@"ask_revoke_sig.okay" optional:YES];
		[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
		if (description) {
			NSArray *lines = [description componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
			}
		}
		[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Revoke signature failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil]];
	}
}

- (void)removeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(id <KeyFingerprint>)key { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	NSInteger uid = [self indexOfUserID:userID.hashID fromKey:key];
	
	if (uid > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		[order addCmd:@"delsig\n" prompt:@"keyedit.prompt"];
		
		NSArray *userIDsignatures = userID.signatures;
		for (GPGKeySignature *aSignature in userIDsignatures) {
			if (aSignature == signature) {
				[order addCmd:@"y\n" prompt:@"keyedit.delsig.valid"];
				if ([[signature keyID] isEqualToString:getKeyID(key.description)]) {
					[order addCmd:@"y\n" prompt:@"keyedit.delsig.selfsig"];
				}
			} else {
				[order addCmd:@"n\n" prompt:@"keyedit.delsig.valid"];
			}
		}
		
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Remove signature failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil]];
	}
}


#pragma mark Working with Subkeys

- (void)removeSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key {
	NSInteger index = [self indexOfSubkey:subkey fromKey:key];
	
	if (index > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
		[order addCmd:@"delkey\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Remove subkey failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"Subkey not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]];
	}
}

- (void)revokeSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description {
	NSInteger index = [self indexOfSubkey:subkey fromKey:key];
	
	if (index > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
		[order addCmd:@"revkey\n" prompt:@"keyedit.prompt"];
		[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
		if (description) {
			NSArray *lines = [description componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
			}
		}
		[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Revoke subkey failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"Subkey not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]];
	}
}

- (void)addSubkeyToKey:(id <KeyFingerprint>)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addCmd:@"addkey\n" prompt:@"keyedit.prompt"];
	[order addInt:type prompt:@"keygen.algo"];
	[order addInt:length prompt:@"keygen.size"];
	[order addInt:daysToExpire prompt:@"keygen.valid"];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Add subkey failed!" gpgTask:gpgTask];
	}
}


#pragma mark Working with User IDs

- (void)addUserIDToKey:(id <KeyFingerprint>)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	[order addCmd:@"adduid\n" prompt:@"keyedit.prompt"];
	[order addCmd:name prompt:@"keygen.name"];
	[order addCmd:email prompt:@"keygen.email"];
	[order addCmd:comment prompt:@"keygen.comment"];
	[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
	
	
	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Add userID failed!" gpgTask:gpgTask];
	}
}

- (void)removeUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key {
	NSInteger uid = [self indexOfUserID:hashID fromKey:key];
	
	if (uid > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		[order addCmd:@"deluid\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Remove userID failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]];
	}
}

- (void)revokeUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description {
	NSInteger uid = [self indexOfUserID:hashID fromKey:key];
	
	if (uid > 0) {
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		[order addCmd:@"revuid\n" prompt:@"keyedit.prompt"];
		[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
		if (description) {
			NSArray *lines = [description componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
			}
		}
		[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Revoke userID failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]];
	}
}

- (void)setPrimaryUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key {
	NSInteger uid = [self indexOfUserID:hashID fromKey:key];
	
	if (uid > 0) {
		gpgTask = [GPGTask gpgTask];
		gpgTask.delegate = self;
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:[NSString stringWithFormat:@"%i", uid]];
		[gpgTask addArgument:@"primary"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:@"Set primary userID failed!" gpgTask:gpgTask];
		}
	} else {
		@throw [GPGException exceptionWithName:@"GPGException" reason:@"UserID not found!" userInfo:
				[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]];
	}
}

- (void)addPhotoFromPath:(NSString *)path toKey:(id <KeyFingerprint>)key {
	GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
	
	[order addCmd:path prompt:@"photoid.jpeg.add"];

	gpgTask = [GPGTask gpgTask];
	gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
	gpgTask.delegate = self;
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:@"addphoto"];
	[gpgTask addArgument:@"save"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Add photo failed!" gpgTask:gpgTask];
	}
}


#pragma mark Working with keyserver

- (NSString *)refreshKeysFromServer:(id <EnumerationList>)keys {
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForKeyserver];
	[gpgTask addArgument:@"--refresh-keys"];
	for (id key in keys) {
		[gpgTask addArgument:[key description]];
	}
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Receive keys failed!" gpgTask:gpgTask];
	}
	
	return [gpgTask statusText];
}

- (NSString *)receiveKeysFromServer:(id <EnumerationList>)keys {
	if ([keys count] == 0) {
		[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
	}
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForKeyserver];
	[gpgTask addArgument:@"--recv-keys"];
	for (id key in keys) {
		[gpgTask addArgument:[key description]];
	}
			
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Receive keys failed!" gpgTask:gpgTask];
	}
	
	return [gpgTask statusText];
}

- (void)sendKeysToServer:(id <EnumerationList>)keys {
	if ([keys count] == 0) {
		[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
	}
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForKeyserver];
	[gpgTask addArgument:@"--send-keys"];
	for (id key in keys) {
		[gpgTask addArgument:[key description]];
	}
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Receive keys failed!" gpgTask:gpgTask];
	}
}

- (NSArray *)searchKeysOnServer:(NSString *)pattern {
	gpgTask = [GPGTask gpgTask];
	gpgTask.batchMode = YES;
	[self addArgumentsForKeyserver];
	[gpgTask addArgument:@"--search-keys"];
	[gpgTask addArgument:@"--"];
	[gpgTask addArgument:pattern];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"Search keys failed!" gpgTask:gpgTask];
	}
	
	NSArray *keys = [GPGRemoteKey keysWithListing:gpgTask.outText];
	
	NSLog(@"%@", keys);
	
	return keys;
}



#pragma mark Help methods

- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"indexOfUserID failed!" gpgTask:gpgTask];
	}
	
	NSString *outText = gpgTask.outText;
	
	NSRange range = [outText rangeOfString:[NSString stringWithFormat:@":%@:", hashID]];
	if (range.length != 0) {
		NSInteger index = 0;
		NSArray *lines = [[outText substringToIndex:range.location] componentsSeparatedByString:@"\n"];
		for (NSString *line in lines) {
			if ([line hasPrefix:@"uid:"] || [line hasPrefix:@"uat:"]) {
				index++;
			}
		}
		return index;
	}
	
	return 0;
}

- (NSInteger)indexOfSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key {
	gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:@"indexOfSubkey failed!" gpgTask:gpgTask];
	}
	
	NSString *outText = gpgTask.outText;
	
	
	NSRange range = [outText rangeOfString:[NSString stringWithFormat:@":%@:", [subkey description]]];
	if (range.length != 0) {
		NSInteger index = 0;
		NSArray *lines = [[outText substringToIndex:range.location] componentsSeparatedByString:@"\n"];
		for (NSString *line in lines) {
			if ([line hasPrefix:@"sub:"]) {
				index++;
			}
		}
		return index;
	}
	
	return 0;
}

+ (void)colonListing:(NSString *)colonListing toArray:(NSArray **)array andFingerprints:(NSArray **)fingerprints {
	NSRange searchRange, findRange, lineRange;
	NSString *searchText, *foundText, *foundFingerprint;
	NSUInteger textLength = [colonListing length];
	NSMutableArray *listings = [NSMutableArray arrayWithCapacity:10];
	NSMutableArray *theFingerprints = [NSMutableArray arrayWithCapacity:10];
	
	*array = listings;
	*fingerprints = theFingerprints;
	
	
	
	searchText = @"\npub:";
	if ([colonListing hasPrefix:@"pub:"]) {
		findRange.location = 0;
		findRange.length = 1;	
	} else {
		if ([colonListing hasPrefix:@"sec:"]) {
			findRange.location = 0;
			findRange.length = 1;
			searchText = @"\nsec:";
		} else {
			findRange = [colonListing rangeOfString:searchText];
			if (findRange.length == 0) {
				searchText = @"\nsec:";
				findRange = [colonListing rangeOfString:searchText];
				if (findRange.length == 0) {
					return;
				}
			}
			findRange.location++;
		}
	}
	
	lineRange = [colonListing lineRangeForRange:findRange];
	
	searchRange.location = lineRange.location + lineRange.length;
	searchRange.length = textLength - searchRange.location;
	
	while ((findRange = [colonListing rangeOfString:searchText options:NSLiteralSearch range:searchRange]).length > 0) {
		findRange.location++;
		lineRange.length = findRange.location - lineRange.location;
		
		foundText = [colonListing substringWithRange:lineRange];
		
		
		lineRange = [foundText rangeOfString:@"\nfpr:"];
		if (lineRange.length == 0) {
			return; //Fehler!
		}
		lineRange.location++;
		lineRange = [foundText lineRangeForRange:lineRange];
		foundFingerprint = [[[foundText substringWithRange:lineRange] componentsSeparatedByString:@":"] objectAtIndex:9];
		
		[listings addObject:[foundText componentsSeparatedByString:@"\n"]];
		[theFingerprints addObject:foundFingerprint];
		
		lineRange = [colonListing lineRangeForRange:findRange];
		searchRange.location = lineRange.location + lineRange.length;
		searchRange.length = textLength - searchRange.location;
	}
	
	
	lineRange.length = textLength - lineRange.location;
	
	foundText = [colonListing substringWithRange:lineRange];
	
	lineRange = [foundText rangeOfString:@"\nfpr:"];
	if (lineRange.length == 0) {
		return; //Fehler!
	}
	lineRange.location++;
	lineRange = [foundText lineRangeForRange:lineRange];
	foundFingerprint = [[[foundText substringWithRange:lineRange] componentsSeparatedByString:@":"] objectAtIndex:9];
	
	[listings addObject:[foundText componentsSeparatedByString:@"\n"]];
	[theFingerprints addObject:foundFingerprint];
}

+ (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing {
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



#pragma mark Delegate method

- (id)gpgTask:(GPGTask *)task statusCode:(NSInteger)status prompt:(NSString *)prompt {
	switch (status) {
		case GPG_STATUS_GET_LINE:
		case GPG_STATUS_GET_BOOL:
		case GPG_STATUS_GET_HIDDEN: {
			GPGTaskOrder *order = [[task userInfo] objectForKey:@"order"];;
			if (order && [order isKindOfClass:[GPGTaskOrder class]]) {
				NSString *cmd = [order cmdForPrompt:prompt statusCode:status];
				if (cmd && ![cmd hasSuffix:@"\n"]) {
					cmd = [cmd stringByAppendingString:@"\n"];
				}
				return cmd;
			}
			break; }
		case GPG_STATUS_GOODSIG:
		case GPG_STATUS_EXPSIG:
		case GPG_STATUS_EXPKEYSIG:
		case GPG_STATUS_BADSIG:
		case GPG_STATUS_ERRSIG:
		case GPG_STATUS_REVKEYSIG:
			if (lastSignature && lastSignature.hasFilled) {
				self.lastSignature = nil;
			}
			//Dont’t break!
		case GPG_STATUS_NEWSIG:
		case GPG_STATUS_VALIDSIG:
		case GPG_STATUS_TRUST_UNDEFINED:
		case GPG_STATUS_TRUST_NEVER:
		case GPG_STATUS_TRUST_MARGINAL:
		case GPG_STATUS_TRUST_FULLY:
		case GPG_STATUS_TRUST_ULTIMATE:
			if (!lastSignature) {
				self.lastSignature = [[[GPGSignature alloc] init] autorelease];
				[signatures addObject:lastSignature];
			}
			
			[lastSignature addInfoFromStatusCode:status andPrompt:prompt];
			break;
	}
	return nil;
}

- (void)gpgTaskWillStart:(GPGTask *)gpgTask {
	if ([signatures count] > 0) {
		self.lastSignature = nil;
		[signatures release];
		signatures = [[NSMutableArray alloc] init];	
	}
}



#pragma mark Notify delegate


- (void)handleException:(NSException *)e {
	if ([delegate respondsToSelector:@selector(gpgController:operationDidFailWithException:)]) {
		[delegate gpgController:self operationDidFailWithException:e];
	}
}

- (void)operationDidFinishWithReturnValue:(id)value {
	if ([delegate respondsToSelector:@selector(gpgController:operationDidFinishWithReturnValue:)]) {
		[delegate gpgController:self operationDidFinishWithReturnValue:value];
	}
}



#pragma mark Private


- (void)addArgumentsForSignerKeys {
	for (GPGKey *key in signerKeys) {
		[gpgTask addArgument:@"-u"];
		[gpgTask addArgument:[key description]];		
	}
}

- (void)addArgumentsForKeyserver {
	if (keyserver) {
		[gpgTask addArgument:@"--keyserver"];
		[gpgTask addArgument:keyserver];		
	}
}

- (void)addArgumentsForComments {
	if (!useDefaultComments) {
		[gpgTask addArgument:@"--no-comments"];
	}
	for (NSString *comment in comments) {
		[gpgTask addArgument:@"--comment"];
		[gpgTask addArgument:comment];
	}
}

- (void)addArgumentsForOptions {
	[gpgTask addArgument:useArmor ? @"--armor" : @"--no-armor"];
	[gpgTask addArgument:useTextMode ? @"--textmode" : @"--no-textmode"];
	[gpgTask addArgument:printVersion ? @"--emit-version" : @"--no-emit-version"];
	if (trustAllKeys) {
		[gpgTask addArgument:@"--trust-model"];
		[gpgTask addArgument:@"always"];
	}
}


- (void)updateKeysWithDict:(NSDictionary *)aDict {
	NSArray *listings = [aDict objectForKey:@"listings"];	
	NSArray *fingerprints = [aDict objectForKey:@"fingerprints"];
	NSSet *secKeyFingerprints = [aDict objectForKey:@"secKeyFingerprints"];
	NSSet *keysToUpdate = [aDict objectForKey:@"keysToUpdate"];
	NSSet **updatedKeys = [[aDict objectForKey:@"updatedKeys"] pointerValue];
	BOOL withSigs = [[aDict objectForKey:@"withSigs"] boolValue];
	
	
	NSMutableSet *updatedKeysSet = [NSMutableSet setWithCapacity:[fingerprints count]];
	
	NSUInteger i, count = [fingerprints count];
	for (i = 0; i < count; i++) {
		NSString *fingerprint = [fingerprints objectAtIndex:i];
		NSArray *listing = [listings objectAtIndex:i];
		
		
		GPGKey *key = [keysToUpdate member:fingerprint];
		BOOL secret = [secKeyFingerprints containsObject:fingerprint];
		if (key && [key isKindOfClass:[GPGKey class]]) {
			[key updateWithListing:listing isSecret:secret withSigs:withSigs];
		} else {
			key = [GPGKey keyWithListing:listing fingerprint:fingerprint isSecret:secret withSigs:withSigs];
		}
		[updatedKeysSet addObject:key];
	}
	
	*updatedKeys = [[updatedKeysSet copy] autorelease];
}

- (void)dealloc {
	[signerKeys release];
	[comments release];
	[signatures release];
	self.keyserver = nil;
	self.userInfo = nil;
	self.lastSignature = nil;
	[asyncProxy release];
	
	[super dealloc];
}

@end



