/*
 Copyright © Roman Zechmeister, 2014
 
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

#import "Libmacgpg.h"
#import "GPGTaskOrder.h"
#import "GPGTypesRW.h"
#import "GPGKeyserver.h"
#import "GPGTaskHelper.h"
#import "GPGWatcher.h"
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
#import "GPGTaskHelperXPC.h"
#import "NSBundle+Sandbox.h"
#endif

#define cancelCheck if (canceled) {@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Operation cancelled") errorCode:GPGErrorCancelled];}


@interface GPGController () <GPGTaskDelegate>
@property (nonatomic, retain) GPGSignature *lastSignature;
@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) GPGTask *gpgTask;
- (void)addArgumentsForKeyserver;
- (void)addArgumentsForSignerKeys;
- (void)addArgumentsForComments;
- (void)addArgumentsForOptions;
- (void)operationDidStart;
- (void)handleException:(NSException *)e;
- (void)operationDidFinishWithReturnValue:(id)value;
- (void)keysHaveChanged:(NSNotification *)notification;
- (void)cleanAfterOperation;
- (void)keysChanged:(NSObject <EnumerationList> *)keys;
- (void)keyChanged:(NSObject <KeyFingerprint> *)key;
+ (GPGErrorCode)readGPGConfig;
+ (GPGErrorCode)readGPGConfigError:(NSException **)error;
- (void)setLastReturnValue:(id)value;
- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName;
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys;
- (void)logException:(NSException *)e;
@end


@implementation GPGController
@synthesize delegate, keyserver, keyserverTimeout, proxyServer, async, userInfo, useArmor, useTextMode, printVersion, useDefaultComments,
trustAllKeys, signatures, lastSignature, gpgHome, passphrase, verbose, autoKeyRetrieve, lastReturnValue, error, undoManager, hashAlgorithm,
timeout, filename, forceFilename, pinentryInfo=_pinentryInfo, allowNonSelfsignedUid, allowWeakDigestAlgos;

NSString *gpgVersion = nil;
NSSet *publicKeyAlgorithm = nil, *cipherAlgorithm = nil, *digestAlgorithm = nil, *compressAlgorithm = nil;
BOOL gpgConfigReaded = NO;



+ (NSString *)gpgVersion {
	[self readGPGConfig];
	return gpgVersion;
}
+ (NSSet *)publicKeyAlgorithm {
	[self readGPGConfig];
	return publicKeyAlgorithm;
}
+ (NSSet *)cipherAlgorithm {
	[self readGPGConfig];
	return cipherAlgorithm;
}
+ (NSSet *)digestAlgorithm {
	[self readGPGConfig];
	return digestAlgorithm;
}
+ (NSSet *)compressAlgorithm {
	[self readGPGConfig];
	return compressAlgorithm;
}

+ (NSString *)nameForHashAlgorithm:(GPGHashAlgorithm)hashAlgorithm {
    NSString *hashAlgorithmName = nil;
    
    switch (hashAlgorithm) {
        case GPGHashAlgorithmMD5:
            hashAlgorithmName = @"md5";
            break;
        
        case GPGHashAlgorithmSHA1:
            hashAlgorithmName = @"sha1";
            break;
        
        case GPGHashAlgorithmRMD160:
            hashAlgorithmName = @"ripemd160";
            break;
        
        case GPGHashAlgorithmSHA256:
            hashAlgorithmName = @"sha256";
            break;
        
        case GPGHashAlgorithmSHA384:
            hashAlgorithmName = @"sha384";
            break;
        
        case GPGHashAlgorithmSHA512:
            hashAlgorithmName = @"sha512";
            break;
        
        case GPGHashAlgorithmSHA224:
            hashAlgorithmName = @"sha225";
            break;
            
        default:
            break;
    }
    
    return hashAlgorithmName;
}




- (NSArray *)comments {
	return [[comments copy] autorelease];
}
- (NSArray *)signerKeys {
	return [[signerKeys copy] autorelease];
}
- (void)setComment:(NSString *)comment {
	[self willChangeValueForKey:@"comments"];
	[comments removeAllObjects];
	if (comment) {
		[comments addObject:comment];
	}
	[self didChangeValueForKey:@"comments"];
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
- (void)setSignerKey:(NSObject <KeyFingerprint> *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeAllObjects];
	if (signerKey) {
		[signerKeys addObject:signerKey];
	}
	[self didChangeValueForKey:@"signerKeys"];
}
- (void)addSignerKey:(NSObject <KeyFingerprint> *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys addObject:signerKey];
	[self didChangeValueForKey:@"signerKeys"];
}
- (void)removeSignerKeyAtIndex:(NSUInteger)index {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeObjectAtIndex:index];
	[self didChangeValueForKey:@"signerKeys"];
}
- (BOOL)decryptionOkay {
	return [[gpgTask.statusDict objectForKey:@"DECRYPTION_OKAY"] boolValue];
}
- (NSDictionary *)statusDict {
	return gpgTask.statusDict;
}
- (void)setGpgTask:(GPGTask *)value {
	if (value != gpgTask) {
		GPGTask *old = gpgTask;
		gpgTask = [value retain];
		[old release];
	}
}
- (GPGTask *)gpgTask {
	return [[gpgTask retain] autorelease];
}


#pragma mark Init

+ (id)gpgController {
	return [[[[self class] alloc] init] autorelease];
}

- (id)init {
	if ((self = [super init]) == nil) {
		return nil;
	}
	
	
	identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];
	comments = [[NSMutableArray alloc] init];
	signerKeys = [[NSMutableArray alloc] init];
	signatures = [[NSMutableArray alloc] init];
	gpgKeyservers = [[NSMutableSet alloc] init];
	keyserverTimeout = 20;
	asyncProxy = [[AsyncProxy alloc] initWithRealObject:self];
	useDefaultComments = YES;
	
	GPGOptions *options = [GPGOptions sharedOptions];
	id value;
	
	if ((value = [options valueInGPGConfForKey:@"armor"])) {
		GPGDebugLog(@"armor: %@", value);
		useArmor = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"emit-version"])) {
		GPGDebugLog(@"emit-version: %@", value);
		printVersion = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"textmode"])) {
		GPGDebugLog(@"textmode: %@", value);
		useTextMode = [value boolValue];
	}
	if ((value = [options valueInGPGConfForKey:@"keyserver-options"])) {
		GPGDebugLog(@"keyserver-options: %@", value);
		if ([value respondsToSelector:@selector(containsObject:)]) {
			if ([value containsObject:@"no-auto-key-retrieve"]) {
				autoKeyRetrieve = NO;
			} else if ([value containsObject:@"auto-key-retrieve"]) {
				autoKeyRetrieve = YES;
			}
		}
	}
	
	return self;
}


- (void)cancel {
	canceled = YES;
	if (gpgTask.isRunning) {
		[gpgTask cancel];
	}
	for (GPGKeyserver *server in gpgKeyservers) {
		if (server.isRunning) {
			[server cancel];
		}
	}
}


#pragma mark Encrypt, decrypt, sign and verify

- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy processData:data withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
		return nil;
	}

    GPGMemoryStream *output = [[GPGMemoryStream alloc] init];
    GPGMemoryStream *input = [GPGMemoryStream memoryStreamForReading:data];

    [self operationDidStart];
    [self processTo:output data:input withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
	[self cleanAfterOperation];
	NSData *processedData = [output readAllData];
	[self operationDidFinishWithReturnValue:processedData];
	[output release];
	return processedData;
}

- (void)processTo:(GPGStream *)output data:(GPGStream *)input withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject<EnumerationList> *)recipients hiddenRecipients:(NSObject<EnumerationList> *)hiddenRecipients {
    // asyncProxy not recognized here

	@try {		
		if ((mode & (GPGEncryptFlags | GPGSignFlags)) == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Unknown mode: %i!", mode];
		}
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
		// Should be YES maybe, but detached sign doesn't ask for a passphrase
		// so, basically, it's NO until further testing.
		gpgTask.batchMode = NO;
		
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
		
		if ((mode & GPGSeparateSign) && (mode & GPGEncryptFlags)) {
			// save object; processTo: will overwrite without releasing
			GPGTask *tempTask = gpgTask;

			// create new in-memory writeable stream
			GPGMemoryStream *sigoutput = [GPGMemoryStream memoryStream];
			[self processTo:sigoutput data:input withEncryptSignMode:mode & ~(GPGEncryptFlags | GPGSeparateSign) recipients:nil hiddenRecipients:nil];
			input = sigoutput;

			// reset back to the outer gpg task
			self.gpgTask = tempTask;
		} else {
			switch (mode & GPGSignFlags & ~GPGSeparateSign) {
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
					if (mode & GPGSeparateSign) {
						[gpgTask addArgument:@"--sign"];
					}
					break;
				default:			
					[NSException raise:NSInvalidArgumentException format:@"Unknown sign mode: %i!", mode & GPGSignFlags];
					break;
			}			
		}
		if (self.forceFilename) {
			[gpgTask addArgument:@"--set-filename"];
			[gpgTask addArgument:self.forceFilename];
		}
		
		gpgTask.outStream = output;
		[gpgTask addInput:input];

		if ([gpgTask start] != 0 && gpgTask.outData.length == 0) { // Check outData because gpg sometime returns an exitcode != 0, but the data is correct encrypted/signed. 
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Encrypt/sign failed!") gpgTask:gpgTask];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	}	
}

- (NSData *)decryptData:(NSData *)data {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy decryptData:data];
		return nil;
	}
    
    GPGMemoryStream *output = [GPGMemoryStream memoryStream];
    GPGMemoryStream *input = [GPGMemoryStream memoryStreamForReading:data];

    [self operationDidStart];    
    [self decryptTo:output data:input];
    NSData *retVal = [output readAllData];
    [self cleanAfterOperation];
    [self operationDidFinishWithReturnValue:retVal];	
    return retVal;
}

- (void)decryptTo:(GPGStream *)output data:(GPGStream *)input {
	@try {
		input = [GPGUnArmor unArmor:input];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addInput:input];
		gpgTask.outStream = output;
		
		[gpgTask addArgument:@"--decrypt"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Decrypt failed!") gpgTask:gpgTask];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	}
}

- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy verifySignature:signatureData originalData:originalData];
		return nil;
	}
    
    GPGMemoryStream *signatureInput = [GPGMemoryStream memoryStreamForReading:signatureData];
    GPGMemoryStream *originalInput = nil;
    if (originalData)
        originalInput = [GPGMemoryStream memoryStreamForReading:originalData];
    return [self verifySignatureOf:signatureInput originalData:originalInput];
}

- (NSArray *)verifySignatureOf:(GPGStream *)signatureInput originalData:(GPGStream *)originalInput {
#warning There's a good chance verifySignature will modify the keys if auto-retrieve-keys is set. In that case it might make sense, that we send the notification ourselves with the potential key which might get imported. We do have the fingerprint, and there's no need to rebuild the whole keyring only to update one key.
	
	NSArray *retVal;
	@try {
		[self operationDidStart];

		NSData *originalData = nil;
		signatureInput = [GPGUnArmor unArmor:signatureInput clearText:originalInput ? nil : &originalData];
		if (originalData) {
			originalInput = [GPGMemoryStream memoryStreamForReading:originalData];
		}
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addInput:signatureInput];
		if (originalInput) {
			[gpgTask addInput:originalInput];
		}
		
		[gpgTask addArgument:@"--verify"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Verify failed!") gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		retVal = self.signatures;
		[self cleanAfterOperation];
		[self operationDidFinishWithReturnValue:retVal];	
	}
	
	return retVal;
}

- (NSArray *)verifySignedData:(NSData *)signedData {
	return [self verifySignature:signedData originalData:nil];
}




#pragma mark Edit keys

- (NSString *)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(int)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(int)subkeyLength
				  daysToExpire:(int)daysToExpire preferences:(NSString *)preferences {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateNewKeyWithName:name email:email comment:comment 
								   keyType:keyType keyLength:keyLength subkeyType:subkeyType subkeyLength:subkeyLength 
							  daysToExpire:daysToExpire preferences:preferences];
		return nil;
	}
	NSString *fingerprint = nil;
	@try {
		[self operationDidStart];
		
		NSMutableString *cmdText = [NSMutableString string];
		
		
		[cmdText appendFormat:@"Key-Type: %i\n", keyType];
		[cmdText appendFormat:@"Key-Length: %i\n", keyLength];
		
		if(keyType == GPG_RSAAlgorithm || keyType == GPG_DSAAlgorithm) {
			[cmdText appendFormat:@"Key-Usage: %@\n", @"sign"];
		}
		
		if (subkeyType) {
			[cmdText appendFormat:@"Subkey-Type: %i\n", subkeyType];
			[cmdText appendFormat:@"Subkey-Length: %i\n", subkeyLength];
			if(keyType == GPG_RSAAlgorithm || keyType == GPG_ElgamalEncryptOnlyAlgorithm) {
				[cmdText appendFormat:@"Subkey-Usage: %@\n", @"encrypt"];
			}
		}
		
		[cmdText appendFormat:@"Name-Real: %@\n", name];
		if ([email length] > 0) {
			[cmdText appendFormat:@"Name-Email: %@\n", email];
		}
		if ([comment length] > 0) {
			[cmdText appendFormat:@"Name-Comment: %@\n", comment];
		}
		
		[cmdText appendFormat:@"Expire-Date: %i\n", daysToExpire];
		
		if (preferences) {
			[cmdText appendFormat:@"Preferences: %@\n", preferences];
		}
		
		[cmdText appendString:@"%ask-passphrase\n"];
		[cmdText appendString:@"%commit\n"];
		
		self.gpgTask = [GPGTask gpgTaskWithArgument:@"--gen-key"];
		[self addArgumentsForOptions];
		gpgTask.batchMode = YES;
		[gpgTask addInText:cmdText];
		
		
		[gpgTask start];
			
		NSString *statusText = gpgTask.statusText;

		NSRange range = [statusText rangeOfString:@"[GNUPG:] KEY_CREATED "];
		if (range.length > 0) {
			range = [statusText lineRangeForRange:range];
			range.length--;
			fingerprint = [[[statusText substringWithRange:range] componentsSeparatedByString:@" "] objectAtIndex:3];
			
			if ([undoManager isUndoRegistrationEnabled]) {
				[[undoManager prepareWithInvocationTarget:self] deleteKeys:[NSSet setWithObject:fingerprint] withMode:GPGDeletePublicAndSecretKey];
				[undoManager setActionName:localizedLibmacgpgString(@"Undo_NewKey")];
			}
			
			[[GPGKeyManager sharedInstance] loadKeys:[NSSet setWithObject:fingerprint] fetchSignatures:NO fetchUserAttributes:NO];
			[self keyChanged:fingerprint];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Generate new key failed!") gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:fingerprint];
	return fingerprint;
}

- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy deleteKeys:keys withMode:mode];
		return;
	}
	@try {
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_Delete"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:[GPGTaskOrder orderWithYesToAll] forKey:@"order"]; 
		
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
			@throw [GPGException exceptionWithReason:[NSString stringWithFormat:localizedLibmacgpgString(@"Delete keys (%@) failed!"), keys] gpgTask:gpgTask];
		}
		
		[self keysChanged:nil]; //TODO: Probleme verhindern, wenn die gelöschten Schlüssel angegeben werden.
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)cleanKeys:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy cleanKeys:keys];
		return;
	}
	@try {
		groupedKeyChange++;
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_CleanKey"];
		
		for (GPGKey *key in keys) {
			[self cleanKey:key];
		}

	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		groupedKeyChange--;
		[self keysChanged:keys];
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)cleanKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy cleanKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_CleanKey"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"clean"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Clean failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)minimizeKeys:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy minimizeKeys:keys];
		return;
	}
	@try {
		groupedKeyChange++;
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_MinimizeKey"];
		
		for (GPGKey *key in keys) {
			[self minimizeKey:key];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		groupedKeyChange--;
		[self keysChanged:keys];
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)minimizeKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy minimizeKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_MinimizeKey"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"minimize"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Minimize failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (NSData *)generateRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateRevokeCertificateForKey:key reason:reason description:description];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addInt:reason prompt:@"ask_revocation_reason.code" optional:YES];
		if (description) {
			NSArray *lines = [description componentsSeparatedByString:@"\n"];
			for (NSString *line in lines) {
				[order addCmd:line prompt:@"ask_revocation_reason.text" optional:YES];
			}
		}
		[order addCmd:@"\n" prompt:@"ask_revocation_reason.text" optional:YES];
		[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"-a"];
		[gpgTask addArgument:@"--gen-revoke"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0 || gpgTask.outData.length == 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Generate revoke certificate failed!") gpgTask:gpgTask];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}

	NSData *retVal = [gpgTask outData];
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeKey"];
		
		NSData *revocationData = [self generateRevokeCertificateForKey:key reason:reason description:description];
		[self importFromData:revocationData fullImport:YES];
		// Keys have been changed, so trigger a KeyChanged Notification.
		[self keyChanged:key];
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)setExpirationDateForSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key daysToExpire:(NSInteger)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setExpirationDateForSubkey:subkey fromKey:key daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_ChangeExpirationDate"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		if (subkey) {
			int index = [self indexOfSubkey:subkey fromKey:key];
			if (index > 0) {
				[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
			} else {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Subkey not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil] errorCode:GPGErrorSubkeyNotFound gpgTask:nil];
			}
		}
		
		[order addCmd:@"expire\n" prompt:@"keyedit.prompt"];
		[order addInt:daysToExpire prompt:@"keygen.valid"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Change expiration date failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)changePassphraseForKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy changePassphraseForKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_ChangePassphrase"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArguments:@[@"--passwd", key.description]];
		gpgTask.userInfo = @{@"order": order};
		
		if ([gpgTask start] != 0) {
			
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Change passphrase failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


- (NSArray *)algorithmPreferencesForKey:(GPGKey *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"--edit-key"];
	[gpgTask addArgument:[key description]];
	[gpgTask addArgument:@"quit"];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"algorithmPreferencesForKey: failed!") gpgTask:gpgTask];
	}
	
	NSMutableArray *list = [NSMutableArray array];
	
	NSArray *lines = [gpgTask.outText componentsSeparatedByString:@"\n"];
	
	for (NSString *line in lines) {
		if ([line hasPrefix:@"uid:"]) {
			NSArray *parts = [line componentsSeparatedByString:@":"];
			NSArray *split = [[parts objectAtIndex:12] componentsSeparatedByString:@","];
			NSString *userIDDescription = [parts objectAtIndex:9];
			NSString *prefs = [split objectAtIndex:0];
			
			NSRange range, searchRange;
			NSUInteger stringLength = [prefs length];
			searchRange.location = 0;
			searchRange.length = stringLength;
			
			NSArray *compressPreferences, *digestPreferences, *cipherPreferences;
			
			range = [prefs rangeOfString:@"Z" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				compressPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				compressPreferences = [NSArray array];
			}
			
			range = [prefs rangeOfString:@"H" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				digestPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				digestPreferences = [NSArray array];
			}
			
			range = [prefs rangeOfString:@"S" options:NSLiteralSearch range:searchRange];
			if (range.length > 0) {
				range.length = searchRange.length - range.location;
				searchRange.length = range.location - 1;
				if (searchRange.length == NSUIntegerMax) {
					searchRange.length = 0;
				}
				cipherPreferences = [[prefs substringWithRange:range] componentsSeparatedByString:@" "];
			} else {
				searchRange.length = stringLength;
				cipherPreferences = [NSArray array];
			}
			
			//TODO: Support for [mdc] [no-ks-modify]!
			NSDictionary *preferences = @{@"userIDDescription":userIDDescription, @"compressPreferences":compressPreferences, @"digestPreferences":digestPreferences, @"cipherPreferences":cipherPreferences};
			[list addObject:preferences];
		}
	}

	return list;
}




- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setAlgorithmPreferences:preferences forUserID:hashID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AlgorithmPreferences"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		if (hashID) {
			int uid = [self indexOfUserID:hashID fromKey:key];
			
			if (uid <= 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
			}
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		}
		[order addCmd:[NSString stringWithFormat:@"setpref %@\n", preferences] prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set preferences failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)key:(NSObject <KeyFingerprint> *)key setDisabled:(BOOL)disabled {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy key:key setDisabled:disabled];
		return;
	}
	@try {
		[self operationDidStart];
		//No undo for this operation.
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:disabled ? @"disable" : @"enable"];
		[gpgTask addArgument:@"quit"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(disabled ? @"Disable key failed!" : @"Enable key failed!") gpgTask:gpgTask];			
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrust:(GPGValidity)trust {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy key:key setOwnerTrsut:trust];
		return;
	}
	@try {
		[self operationDidStart];
		//No undo for this operation.
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"trust\n" prompt:@"keyedit.prompt"];
		[order addInt:trust prompt:@"edit_ownertrust.value"];
		[order addCmd:@"quit\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set trust failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];
}

- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust {
	[self key:key setOwnerTrust:trust];
}


#pragma mark Import and export

- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport {
	NSString *statusText = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy importFromData:data fullImport:fullImport];
		return nil;
	}
	@try {
		
		
        NSData *dataToCheck = data;
        NSSet *keys = nil;
		int i = 3; // Max 3 loops.
        
        while (dataToCheck.length > 0 && i-- > 0) {
			NSData *unchangedData = dataToCheck;
			BOOL encrypted = NO;

			NSData *tempData = dataToCheck;
			if (tempData.isArmored) {
				GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:tempData]];
				tempData = [unArmor decodeAll];
			}
            keys = [self keysInExportedData:tempData encrypted:&encrypted];

            if (keys.count > 0) {
                data = tempData;
                break;
            } else if (encrypted) {
				// Decrypt to allow import of encrypted keys.
				dataToCheck = [self decryptData:dataToCheck];
				if (dataToCheck.isArmored) {
					GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:dataToCheck]];
					dataToCheck = [unArmor decodeAll];
				}
			} else if (dataToCheck.length > 4 && memcmp(dataToCheck.bytes, "{\\rtf", 4) == 0) {
				// Data is RTF encoded.
				
				//Get keys from RTF data.
				dataToCheck = [[[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:nil error:nil] string] dataUsingEncoding:NSUTF8StringEncoding];
				if (dataToCheck.isArmored) {
					GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:[GPGMemoryStream memoryStreamForReading:dataToCheck]];
					dataToCheck = [unArmor decodeAll];
				}
			}
			if (unchangedData == dataToCheck) {
				break;
			}
        }
		
		
		
		//TODO: Uncomment the following lines when keysInExportedData: fully works!
		/*if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"No keys to import!"];
		}*/
		
		
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_Import"];
		
		//GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		//gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addInData:data];
		[gpgTask addArgument:@"--import"];
		if (fullImport) {
			[gpgTask addArgument:@"--import-options"];
			[gpgTask addArgument:@"import-local-sigs"];
			[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
			[gpgTask addArgument:@"--allow-weak-digest-algos"];
		}
		
		
		[gpgTask start];
		
		statusText = gpgTask.statusText;
		
		
		NSRange range = [statusText rangeOfString:@"[GNUPG:] IMPORT_RES "];
		
		if (range.length == 0 || [statusText characterAtIndex:range.location + range.length] == '0') {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Import failed!") gpgTask:gpgTask];
		}
		
		[self keysChanged:keys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:statusText];	
	return statusText;
}

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys options:(GPGExportOptions)options {
	NSData *exportedData = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy exportKeys:keys options:options];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
		[arguments addObject:@"--export"];
		
		NSMutableArray *exportOptions = [NSMutableArray array];
		if (options & GPGExportAttributes) {
			[exportOptions addObject:@"export-attributes"];
		}
		if (options & GPGExportClean) {
			[exportOptions addObject:@"export-clean"];
		}
		if (options & GPGExportLocalSigs) {
			[exportOptions addObject:@"export-local-sigs"];
		}
		if (options & GPGExportMinimal) {
			[exportOptions addObject:@"export-minimal"];
		}
		if (options & GPGExportResetSubkeyPassword) {
			[exportOptions addObject:@"export-reset-subkey-passwd"];
		}
		if (options & GPGExportSensitiveRevkeys) {
			[exportOptions addObject:@"export-sensitive-revkeys"];
		}

		if (exportOptions.count) {
			[arguments addObject:@"--export-options"];
			[arguments addObject:[exportOptions componentsJoinedByString:@","]];
		}
		
		
		for (NSObject <KeyFingerprint> * key in keys) {
			[arguments addObject:[key description]];
		}
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForComments];
		[gpgTask addArguments:arguments];
		
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") gpgTask:gpgTask];
		}
		exportedData = [gpgTask outData];
		
		
		if (options & GPGExportSecretKeys) {
			[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[self addArgumentsForComments];
			[gpgTask addArguments:arguments];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") gpgTask:gpgTask];
			}
			NSMutableData *concatExportedData = [NSMutableData dataWithData:exportedData];
			[concatExportedData appendData:[gpgTask outData]];
            exportedData = concatExportedData;
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:exportedData];
	return exportedData;
}

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	return [self exportKeys:keys options:(fullExport ? GPGExportLocalSigs | GPGExportSensitiveRevkeys : 0) | (allowSec ? GPGExportSecretKeys : 0)];
}


#pragma mark Working with Signatures

- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(int)type local:(BOOL)local daysToExpire:(int)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy signUserID:hashID ofKey:key signKey:signKey type:type local:local daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddSignature"];

		NSString *uid;
		if (!hashID) {
			uid = @"uid *\n";
		} else {
			int uidIndex = [self indexOfUserID:hashID fromKey:key];
			if (uidIndex > 0) {
				uid = [NSString stringWithFormat:@"uid %i\n", uidIndex];
			} else {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
			}
		}
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:uid prompt:@"keyedit.prompt"];
		[order addCmd:local ? @"lsign\n" : @"sign\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"n\n" prompt:@"sign_uid.expire" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", daysToExpire] prompt:@"siggen.valid" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", type] prompt:@"sign_uid.class" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		if (signKey) {
			[gpgTask addArgument:@"-u"];
			[gpgTask addArgument:[signKey description]];
		}
		[gpgTask addArgument:@"--ask-cert-expire"];
		[gpgTask addArgument:@"--ask-cert-level"];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Sign userID failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSignature:signature fromUserID:userID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveSignature"];

		int uid = [self indexOfUserID:userID.hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"delsig\n" prompt:@"keyedit.prompt"];
			
			NSArray *userIDsignatures = userID.signatures;
			for (GPGUserIDSignature *aSignature in userIDsignatures) {
				if (aSignature == signature) {
					[order addCmd:@"y\n" prompt:@[@"keyedit.delsig.valid", @"keyedit.delsig.invalid", @"keyedit.delsig.unknown"]];
					if ([[signature keyID] isEqualToString:[key.description keyID]]) {
						[order addCmd:@"y\n" prompt:@"keyedit.delsig.selfsig"];
					}
				} else {
					[order addCmd:@"n\n" prompt:@[@"keyedit.delsig.valid", @"keyedit.delsig.invalid", @"keyedit.delsig.unknown"]];
				}
			}
			
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove signature failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSignature:signature fromUserID:userID ofKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeSignature"];

		int uid = [self indexOfUserID:userID.hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"revsig\n" prompt:@"keyedit.prompt"];
			
			NSArray *userIDsignatures = userID.signatures;
			for (GPGUserIDSignature *aSignature in userIDsignatures) {
				if (aSignature.revocation == NO && aSignature.primaryKey.secret) {
					if (aSignature == signature) {
						[order addCmd:@"y\n" prompt:@"ask_revoke_sig.one"];
					} else {
						[order addCmd:@"n\n" prompt:@"ask_revoke_sig.one"];
					}
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
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke signature failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with Subkeys

- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addSubkeyToKey:key type:type length:length daysToExpire:daysToExpire];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddSubkey"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"addkey\n" prompt:@"keyedit.prompt"];
		[order addInt:type prompt:@"keygen.algo"];
		[order addInt:length prompt:@"keygen.size"];
		[order addInt:daysToExpire prompt:@"keygen.valid"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add subkey failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSubkey:subkey fromKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveSubkey"];

		int index = [self indexOfSubkey:subkey fromKey:key];
		
		if (index > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
			[order addCmd:@"delkey\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove subkey failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Subkey not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil] errorCode:GPGErrorSubkeyNotFound gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSubkey:subkey fromKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeSubkey"];

		int index = [self indexOfSubkey:subkey fromKey:key];
		
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
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke subkey failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Subkey not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil] errorCode:GPGErrorSubkeyNotFound gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with User IDs

- (void)addUserIDToKey:(NSObject <KeyFingerprint> *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addUserIDToKey:key name:name email:email comment:comment];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddUserID"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"adduid\n" prompt:@"keyedit.prompt"];
		[order addCmd:name prompt:@"keygen.name"];
		[order addCmd:email prompt:@"keygen.email"];
		[order addCmd:comment prompt:@"keygen.comment"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add userID failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeUserID:hashID fromKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveUserID"];
		
		int uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"deluid\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Remove userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeUserID:hashID fromKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeUserID"];
		
		int uid = [self indexOfUserID:hashID fromKey:key];
		
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
			[order addCmd:@"y\n" prompt:@"ask_revocation_reason.okay" optional:YES];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Revoke userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)setPrimaryUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setPrimaryUserID:hashID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_PrimaryUserID"];
		
		int uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			self.gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			[gpgTask addArgument:[NSString stringWithFormat:@"%i", uid]];
			[gpgTask addArgument:@"primary"];
			[gpgTask addArgument:@"save"];
			
			if ([gpgTask start] != 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Set primary userID failed!") gpgTask:gpgTask];
			}
			[self keyChanged:key];
		} else {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)addPhotoFromPath:(NSString *)path toKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addPhotoFromPath:path toKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_AddPhoto"];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		[order addCmd:path prompt:@"photoid.jpeg.add"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"addphoto"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Add photo failed!") gpgTask:gpgTask];
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with keyserver

- (NSString *)refreshKeysFromServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy refreshKeysFromServer:keys];
		return nil;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_RefreshFromServer"];
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--refresh-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Refresh keys failed!") gpgTask:gpgTask];
		}
		[self keysChanged:keys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	NSString *retVal = [gpgTask statusText];
	[self operationDidFinishWithReturnValue:retVal];
	return retVal;
}

- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy receiveKeysFromServer:keys];
		return nil;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_ReceiveFromServer"];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--recv-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0 && ![gpgTask.statusDict objectForKey:@"IMPORT_RES"]) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Receive keys failed!") gpgTask:gpgTask];
		}
		
		NSSet *changedKeys = importedFingerprintsFromStatus(gpgTask.statusDict);
		[self keysChanged:changedKeys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	NSString *retVal = [gpgTask statusText];
	[self operationDidFinishWithReturnValue:retVal];
	return retVal;
}

- (void)sendKeysToServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy sendKeysToServer:keys];
		return;
	}
	@try {
		[self operationDidStart];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--send-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Send keys failed!") gpgTask:gpgTask];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	[self operationDidFinishWithReturnValue:nil];
}

- (NSArray *)searchKeysOnServer:(NSString *)pattern {
	NSArray *keys = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy searchKeysOnServer:pattern];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		
		// Remove all white-spaces.
		NSString *nospacePattern = [[pattern componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
		NSString *stringToCheck = nil;
		
		switch (nospacePattern.length) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = nospacePattern;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([pattern hasPrefix:@"0"]) {
					stringToCheck = [nospacePattern substringFromIndex:1];
				}
				break;
			case 10:
			case 18:
			case 34:
			case 42:
				if ([pattern hasPrefix:@"0x"]) {
					stringToCheck = [nospacePattern substringFromIndex:2];
				}
				break;
		}
		
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet]].length == 0) {
			// The pattern is a keyID or fingerprint.
			pattern = [@"0x" stringByAppendingString:stringToCheck];
		} else {
			// The pattern is any other text.
			pattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		}
		
		
		
		
		self.gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.batchMode = YES;
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--search-keys"];
		[gpgTask addArgument:@"--"];
		[gpgTask addArgument:pattern];
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Search keys failed!") gpgTask:gpgTask];
		}
		
		keys = [GPGRemoteKey keysWithListing:gpgTask.outText];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:keys];
	
	return keys;
}

- (BOOL)testKeyserver {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy testKeyserver];
		return NO;
	}
	BOOL result = NO;
	@try {
		[self operationDidStart];
		self.gpgTask = [GPGTask gpgTask];
		
		GPGTaskOrder *order = [GPGTaskOrder order];
		[order addCmd:@"q\n" prompt:@"keysearch.prompt" optional:YES];
		gpgTask.userInfo = @{@"order": order};
		
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--search-keys"];
		[gpgTask addArgument:@" "];
		
		result = ([gpgTask start] == 0);
	} @catch (NSException *e) {
	} @finally {
		[self cleanAfterOperation];
	}

	[self operationDidFinishWithReturnValue:@(result)];
	return result;
}

/*- (NSString *)refreshKeysFromServer:(NSObject <EnumerationList> *)keys { //DEPRECATED!
	return [self receiveKeysFromServer:keys];
}

- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy receiveKeysFromServer:keys];
		return nil;
	}
	NSString *retVal = nil;
	@try {
		[self operationDidStart];
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		
		
		__block NSException *exception = nil;
		__block int32_t serversRunning = keys.count;
		NSCondition *condition = [NSCondition new];
		[condition lock];
		
		NSMutableData *keysToImport = [NSMutableData data];
		NSLock *dataLock = [NSLock new];
		
		gpg_ks_finishedHandler handler = ^(GPGKeyserver *s) {
			if (s.exception) {
				exception = s.exception;
			} else {
				NSData *unArmored = [GPGPacket unArmor:s.receivedData];
				if (unArmored) {
					[dataLock lock];
					[keysToImport appendData:unArmored];
					[dataLock unlock];
				}
			}
			
			OSAtomicDecrement32Barrier(&serversRunning);
			if (serversRunning == 0) {
				[condition signal];
			}
		};
		
		for (NSString *key in keys) {
			GPGKeyserver *server = [[GPGKeyserver alloc] initWithFinishedHandler:handler];
			server.timeout = self.keyserverTimeout;
			if (self.keyserver) {
				server.keyserver = self.keyserver;
			}
			[gpgKeyservers addObject:server];
			[server getKey:key.description];
			[server release];
		}
		
		while (serversRunning > 0) {
			[condition wait];
		}
		
		[condition unlock];
		[condition release];
		condition = nil;
		
		
		[gpgKeyservers removeAllObjects];
		
		if (exception && keysToImport.length == 0) {
			[self handleException:exception];
		} else {
			retVal = [self importFromData:keysToImport fullImport:NO];
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:retVal];
	return retVal;
}

- (void)sendKeysToServer:(NSObject <EnumerationList> *)keys {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy sendKeysToServer:keys];
		return;
	}
	@try {
		[self operationDidStart];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		
		BOOL oldArmor = self.useArmor;
		self.useArmor = YES;
		NSData *exportedKeys = [self exportKeys:keys allowSecret:NO fullExport:NO];
		self.useArmor = oldArmor;
		
		if (exportedKeys) {
			NSString *armoredKeys = exportedKeys.gpgString;
						
			__block BOOL running = YES;
			NSCondition *condition = [NSCondition new];
			[condition lock];
			
			
			GPGKeyserver *server = [[GPGKeyserver alloc] initWithFinishedHandler:^(GPGKeyserver *s) {
				running = NO;
				[condition signal];
			}];
			server.timeout = self.keyserverTimeout;
			if (self.keyserver) {
				server.keyserver = self.keyserver;
			}
			[gpgKeyservers addObject:server];
			
			[server uploadKeys:armoredKeys];
			
			
			while (running) {
				[condition wait];
			}
			
			[condition unlock];
			[condition release];
			condition = nil;
			
			[gpgKeyservers removeObject:server];
			
			if (server.exception) {
				[self handleException:server.exception];
			}
			
			[server release];
		}		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	[self operationDidFinishWithReturnValue:nil];	
}

- (NSArray *)searchKeysOnServer:(NSString *)pattern {	
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy searchKeysOnServer:pattern];
		return nil;
	}
	
	NSArray *keys = nil;
	
	@try {
		[self operationDidStart];
		
		pattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
		NSString *stringToCheck = nil;
		
		switch ([pattern length]) {
			case 8:
			case 16:
			case 32:
			case 40:
				stringToCheck = pattern;
				break;
			case 9:
			case 17:
			case 33:
			case 41:
				if ([pattern hasPrefix:@"0"]) {
					stringToCheck = [pattern substringFromIndex:1];
				}
				break;
		}
		
		
		if (stringToCheck && [stringToCheck rangeOfCharacterFromSet:noHexCharSet].length == 0) {
			pattern = [@"0x" stringByAppendingString:stringToCheck];
		}

		
		__block BOOL running = YES;
		NSCondition *condition = [NSCondition new];
		[condition lock];
				
		
		GPGKeyserver *server = [[GPGKeyserver alloc] initWithFinishedHandler:^(GPGKeyserver *s) {
			running = NO;
			[condition signal];
		}];
		server.timeout = self.keyserverTimeout;
		if (self.keyserver) {
			server.keyserver = self.keyserver;
		}
		[gpgKeyservers addObject:server];
		
		[server searchKey:pattern];
		
		
		while (running) {
			[condition wait];
		}
		
		[condition unlock];
		[condition release];
		condition = nil;
		
		[gpgKeyservers removeObject:server];
		
		if (server.exception) {
			[self handleException:server.exception];
		} else {
			keys = [GPGRemoteKey keysWithListing:[server.receivedData gpgString]];
		}
		
		[server release];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:keys];
	
	return keys;
}*/



#pragma mark Help methods

- (BOOL)isPassphraseForKeyInCache:(NSObject <KeyFingerprint> *)key {
	return [self isPassphraseForKeyInGPGAgentCache:key] || [self isPassphraseForKeyInKeychain:key];
}

- (BOOL)isPassphraseForKeyInKeychain:(NSObject <KeyFingerprint> *)key {
	NSString *fingerprint = [key description];
	return SecKeychainFindGenericPassword (nil, strlen(GPG_SERVICE_NAME), GPG_SERVICE_NAME, [fingerprint UTF8Length], [fingerprint UTF8String], nil, nil, nil) == 0; 
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSObject <KeyFingerprint> *)key {
	if([GPGTask sandboxed]) {
		GPGTaskHelperXPC *taskHelper = [[GPGTaskHelperXPC alloc] init];
		BOOL inCache = NO;
		@try {
			inCache = [taskHelper isPassphraseForKeyInGPGAgentCache:[key description]];
		}
		@catch (NSException *exception) {
			return NO;
		}
		@finally {
			[taskHelper release];
		}
		
		return inCache;
	}

	return [GPGTaskHelper isPassphraseInGPGAgentCache:(NSObject <KeyFingerprint> *)key];
}

- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"indexOfUserID failed!") gpgTask:gpgTask];
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

- (NSInteger)indexOfSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key {
	self.gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:@"--allow-weak-digest-algos"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"indexOfSubkey failed!") gpgTask:gpgTask];
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

- (NSSet *)keysInExportedData:(NSData *)data encrypted:(BOOL *)encrypted {
	// Returns a set of fingerprints and keyIDs of keys and key-parts (like signatures) in the data.
	
	NSMutableSet *keys = [NSMutableSet set];
	NSMutableSet *keyIDs = [NSMutableSet set];

	
	GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:data];
	GPGPacketParser *parser = [GPGPacketParser packetParserWithStream:stream];
	
	GPGPacket *packet;
	
	while ((packet = parser.nextPacket)) {
		switch (packet.tag) {
			case GPGPublicKeyPacketTag:
			case GPGSecretKeyPacketTag:
			case GPGPublicSubkeyPacketTag:
			case GPGSecretSubkeyPacketTag:
				[keys addObject:[(GPGPublicKeyPacket *)packet fingerprint]];
				break;
			case GPGSymmetricEncryptedSessionKeyPacketTag:
			case GPGPublicKeyEncryptedSessionKeyPacketTag:
				if (encrypted) {
					*encrypted = YES;
				}
				break;
			case GPGSignaturePacketTag: {
				GPGSignaturePacket *signaturePacket = (GPGSignaturePacket *)packet;
				if (signaturePacket.keyID) {
					[keyIDs addObject:signaturePacket.keyID];
				}
				break;
			}
			default:
				break;
		}
	}
	
	if (keyIDs.count > 0) {
		for (NSString *fingerprint in keys) {
			NSString *keyID = fingerprint.keyID;
			[keyIDs removeObject:keyID];
		}
		[keys unionSet:keyIDs];
	}

	return keys;
}



- (void)parseStatusForSignatures:(NSInteger)status prompt:(NSString *)prompt  {
	BOOL parseFingerprint = NO;

	if (status == GPG_STATUS_NEWSIG) {
		return;
	} else if (status >= GPG_STATUS_GOODSIG && status <= GPG_STATUS_ERRSIG) { // New signature
		/*
		 status is one of: GPG_STATUS_GOODSIG, GPG_STATUS_EXPSIG, GPG_STATUS_EXPKEYSIG, GPG_STATUS_REVKEYSIG, GPG_STATUS_BADSIG, GPG_STATUS_ERRSIG
		*/
		self.lastSignature = [[[GPGSignature alloc] init] autorelease];
		[signatures addObject:self.lastSignature];
		parseFingerprint = YES;
	}
	
	
	NSArray *components = [prompt componentsSeparatedByString:@" "];
	
	switch (status) {
		case GPG_STATUS_GOODSIG:
			self.lastSignature.status = GPGErrorNoError;
			break;
		case GPG_STATUS_EXPSIG:
			self.lastSignature.status = GPGErrorSignatureExpired;
			break;
		case GPG_STATUS_EXPKEYSIG:
			self.lastSignature.status = GPGErrorKeyExpired;
			break;
		case GPG_STATUS_BADSIG:
			self.lastSignature.status = GPGErrorBadSignature;
			break;
		case GPG_STATUS_REVKEYSIG:
			self.lastSignature.status = GPGErrorCertificateRevoked;
			break;
		case GPG_STATUS_ERRSIG:
			self.lastSignature.publicKeyAlgorithm = [[components objectAtIndex:1] intValue];
			self.lastSignature.hashAlgorithm = [[components objectAtIndex:2] intValue];
			self.lastSignature.signatureClass = hexToByte([[components objectAtIndex:3] UTF8String]);
			self.lastSignature.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:4]];
			switch ([[components objectAtIndex:5] intValue]) {
				case 4:
					self.lastSignature.status = GPGErrorUnknownAlgorithm;
					break;
				case 9:
					self.lastSignature.status = GPGErrorNoPublicKey;
					break;
				default:
					self.lastSignature.status = GPGErrorGeneralError;
					break;
			}
			break;
			
		case GPG_STATUS_VALIDSIG:
			parseFingerprint = YES;
			self.lastSignature.creationDate = [NSDate dateWithGPGString:[components objectAtIndex:2]];
			self.lastSignature.expirationDate = [NSDate dateWithGPGString:[components objectAtIndex:3]];
			self.lastSignature.version = [[components objectAtIndex:4] intValue];
			self.lastSignature.publicKeyAlgorithm = [[components objectAtIndex:6] intValue];
			self.lastSignature.hashAlgorithm = [[components objectAtIndex:7] intValue];
			self.lastSignature.signatureClass = hexToByte([[components objectAtIndex:8] UTF8String]);
			break;
		case GPG_STATUS_TRUST_UNDEFINED:
			self.lastSignature.trust = GPGValidityUndefined;
			break;
		case GPG_STATUS_TRUST_NEVER:
			self.lastSignature.trust = GPGValidityNever;
			break;
		case GPG_STATUS_TRUST_MARGINAL:
			self.lastSignature.trust = GPGValidityMarginal;
			break;
		case GPG_STATUS_TRUST_FULLY:
			self.lastSignature.trust = GPGValidityFull;
			break;
		case GPG_STATUS_TRUST_ULTIMATE:
			self.lastSignature.trust = GPGValidityUltimate;
			break;
	}
	
	
	if (parseFingerprint) {
		
		GPGKeyManager *keyManager = [GPGKeyManager sharedInstance];
		NSString *fingerprint = [components objectAtIndex:0];
		GPGKey *key;
		
		if (fingerprint.length == 16) { // KeyID
			key = [keyManager.keysByKeyID objectForKey:fingerprint];
		} else { // Fingerprint
			key = [keyManager.allKeysAndSubkeys member:fingerprint];
			
			// If no key is available, but a fingerprint is available it means that our
			// list of keys is outdated. In that case, the specific key is reloaded.
			if(!key && fingerprint.length >= 32) {
				[keyManager loadKeys:[NSSet setWithObject:fingerprint] fetchSignatures:NO fetchUserAttributes:NO];
				key = [keyManager.allKeysAndSubkeys member:fingerprint];
			}
		}
		
		if (key) {
			self.lastSignature.key = key;
			self.lastSignature.fingerprint = key.fingerprint;
		} else {
			self.lastSignature.fingerprint = fingerprint;
		}
	}
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
			} else {
				return @"\n";
			}
			break; }
			
		case GPG_STATUS_GOODSIG:
		case GPG_STATUS_EXPSIG:
		case GPG_STATUS_EXPKEYSIG:
		case GPG_STATUS_BADSIG:
		case GPG_STATUS_ERRSIG:
		case GPG_STATUS_REVKEYSIG:
		case GPG_STATUS_NEWSIG:
		case GPG_STATUS_VALIDSIG:
		case GPG_STATUS_TRUST_UNDEFINED:
		case GPG_STATUS_TRUST_NEVER:
		case GPG_STATUS_TRUST_MARGINAL:
		case GPG_STATUS_TRUST_FULLY:
		case GPG_STATUS_TRUST_ULTIMATE:
			[self parseStatusForSignatures:status prompt:prompt];
			break;
			
        // Store the hash algorithm.
        case GPG_STATUS_SIG_CREATED: {
            // Split the line by space, index 2 has the hash algorithm.
            NSArray *promptComponents = [prompt componentsSeparatedByString:@" "];
            NSUInteger hashAlgo = 0;
            if([promptComponents count] == 6) {
                NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
                [f setNumberStyle:NSNumberFormatterDecimalStyle];
                NSNumber *algorithmNr = [f numberFromString:[promptComponents objectAtIndex:2]];
                hashAlgo = [algorithmNr unsignedIntegerValue];
                [f release];
            }
            hashAlgorithm = hashAlgo;
            break;
        }
		case GPG_STATUS_PLAINTEXT: {
            NSArray *promptComponents = [prompt componentsSeparatedByString:@" "];
			if (promptComponents.count == 3) {
				NSString *tempFilename = [[promptComponents objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				NSRange extensionRange = [tempFilename rangeOfString:@"."];
				self.filename = tempFilename.length > 0 ? tempFilename : nil;
				
				// For some reason, in some occassions, GPG only prints a number instead
				// of the filename.
				// If the file is a binary file and doesn't have an extension, we'll reset the filename to
				// nil.
				if([[promptComponents objectAtIndex:0] integerValue] == 62 &&
				   (extensionRange.location == NSNotFound || extensionRange.location == 0))
					self.filename = nil;
			}
			break;
		}
	}
	return nil;
}

- (void)gpgTaskWillStart:(GPGTask *)task {
	if ([signatures count] > 0) {
		self.lastSignature = nil;
		[signatures release];
		signatures = [[NSMutableArray alloc] init];	
	}
}

- (void)gpgTask:(GPGTask *)gpgTask progressed:(NSInteger)progressed total:(NSInteger)total {
	[delegate gpgController:self progressed:progressed total:total];
}


#pragma mark Notify delegate

- (void)handleException:(NSException *)e {
	if (asyncStarted && runningOperations == 1 && [delegate respondsToSelector:@selector(gpgController:operationThrownException:)]) {
		[delegate gpgController:self operationThrownException:e];
	}
	[e retain];
	[error release];
	error = e;
	[self logException:e];
}

- (void)operationDidStart {
	if (runningOperations == 0) {
		self.gpgTask = nil;
		[error release];
		error = nil;
		if ([delegate respondsToSelector:@selector(gpgControllerOperationDidStart:)]) {
			[delegate gpgControllerOperationDidStart:self];
		}		
	}
	runningOperations++;
}
- (void)operationDidFinishWithReturnValue:(id)value {
	if (runningOperations == 0) {
		self.lastReturnValue = value;
		if ([delegate respondsToSelector:@selector(gpgController:operationDidFinishWithReturnValue:)]) {
			[delegate gpgController:self operationDidFinishWithReturnValue:value];
		}		
	}
}

- (void)keysHaveChanged:(NSNotification *)notification {
	if (self != notification.object && ![identifier isEqualTo:notification.object] && [delegate respondsToSelector:@selector(gpgController:keysDidChanged:external:)]) {
		NSDictionary *dictionary = notification.userInfo;
		NSObject <EnumerationList> *keys = [dictionary objectForKey:@"keys"];
		
		if (!keys || [keys isKindOfClass:[NSArray class]] || [keys isKindOfClass:[NSSet class]]) {
			[delegate gpgController:self keysDidChanged:keys external:YES];
		}
	}
}



#pragma mark Private

- (void)logException:(NSException *)e {
	GPGDebugLog(@"GPGController: %@", e.description);
	if ([e isKindOfClass:[GPGException class]]) {
		GPGDebugLog(@"Error text: %@\nStatus text: %@", [(GPGException *)e gpgTask].errText, [(GPGException *)e gpgTask].statusText);
	}
}

- (void)keysChanged:(NSObject <EnumerationList> *)keys {
	if (groupedKeyChange == 0) {
		NSDictionary *dictionary = nil;
		if (keys) {
			NSMutableArray *fingerprints = [NSMutableArray arrayWithCapacity:[keys count]];
			for (NSObject *key in keys) {
				[fingerprints addObject:[key description]];
			}
			dictionary = [NSDictionary dictionaryWithObjectsAndKeys:fingerprints, @"keys", nil];
		}
		if ([delegate respondsToSelector:@selector(gpgController:keysDidChanged:external:)]) {
			[delegate gpgController:self keysDidChanged:keys external:NO];
		}
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:dictionary options:NSNotificationPostToAllSessions | NSNotificationDeliverImmediately];
	}
}
- (void)keyChanged:(NSObject <KeyFingerprint> *)key {
	if (key) {
		[self keysChanged:[NSSet setWithObject:key]];
	} else {
		[self keysChanged:nil];
	}
}


- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data { //Löscht die übergebenen Schlüssel und importiert data.
	[self registerUndoForKeys:keys withName:nil];
	
	[undoManager disableUndoRegistration];
	groupedKeyChange++;
	BOOL oldAsync = self.async;
	self.async = NO;
	
	@try {
		[self deleteKeys:keys withMode:GPGDeletePublicAndSecretKey];
	} @catch (NSException *exception) {
	} 
	
	if ([data length] > 0) {
		@try {
			[self importFromData:data fullImport:YES];
		} @catch (NSException *exception) {
		} 
	}
	
	self.async = oldAsync;
	groupedKeyChange--;
	[self keysChanged:keys];
	[undoManager enableUndoRegistration];
}

- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName {
	if ([undoManager isUndoRegistrationEnabled]) {
		BOOL oldAsync = self.async;
		self.async = NO;
		if ([NSThread isMainThread]) {
			[self registerUndoForKeys:keys];
		} else {
			[self performSelectorOnMainThread:@selector(registerUndoForKeys:) withObject:keys waitUntilDone:YES];
		}
		self.async = oldAsync;
		
		if (actionName && ![undoManager isUndoing] && ![undoManager isRedoing]) {
			[undoManager setActionName:localizedLibmacgpgString(actionName)];
		}
	}
}
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName {
	[self registerUndoForKeys:[NSSet setWithObject:key] withName:actionName];
}
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys {
	GPGTask *oldGPGTask = self.gpgTask;
	[[undoManager prepareWithInvocationTarget:self] restoreKeys:keys withData:[self exportKeys:keys allowSecret:YES fullExport:YES]];
	self.gpgTask = oldGPGTask;
} 




- (void)cleanAfterOperation {
	if (runningOperations == 1) {
		asyncStarted = NO;
		canceled = NO;
	}
	runningOperations--;
}

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
	[gpgTask addArgument:@"--keyserver-options"];
	
	NSMutableString *keyserverOptions = [NSMutableString stringWithCapacity:50];
	
	[keyserverOptions appendFormat:@"timeout=%lu", (unsigned long)keyserverTimeout];
	
	[keyserverOptions appendString:autoKeyRetrieve ? @",auto-key-retrieve" : @",no-auto-key-retrieve"];
	
	NSString *proxy = proxyServer ? proxyServer : [[GPGOptions sharedOptions] httpProxy];
	if ([proxy length] > 0) {
		if ([proxy rangeOfString:@"://"].length == 0) {
			proxy = [@"http://" stringByAppendingString:proxy]; 
		}
		[keyserverOptions appendFormat:@",http-proxy=%@", proxy];
	}
	
	
	[gpgTask addArgument:keyserverOptions];
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
	if (gpgHome) {
		[gpgTask addArgument:@"--homedir"];
		[gpgTask addArgument:gpgHome];
	}
	if (allowNonSelfsignedUid) {
		[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
	}
	if (allowWeakDigestAlgos) {
		[gpgTask addArgument:@"--allow-weak-digest-algos"];
	}
	if (_pinentryInfo) {
		NSMutableString *pinentryUserData =  [NSMutableString string];
		for (NSString *key in _pinentryInfo) {
			NSString *value = [_pinentryInfo objectForKey:key];
			NSString *encodedValue = [self encodeStringForPinentry:value];
			[pinentryUserData appendFormat:@"%@=%@,", key, encodedValue];
		}
		NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:pinentryUserData, @"PINENTRY_USER_DATA", nil];
		gpgTask.environmentVariables = env;
	}
	if (passphrase) {
		gpgTask.passphrase = passphrase;
	}
	
	gpgTask.delegate = self;
	if ([delegate respondsToSelector:@selector(gpgController:progressed:total:)]) {
		gpgTask.progressInfo = YES;
	}
}

- (NSString *)encodeStringForPinentry:(NSString *)string {
	const char *chars = [string UTF8String];
	NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	char *newChars = malloc(length * 3);
	if (!newChars) {
		return nil;
	}
	char *charsPointer = newChars;

	char table[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	
	while (*chars) {
		switch (*chars) {
			case ',':
			case '\n':
			case '\r':
				charsPointer[0] = '%';
				charsPointer[1] = table[*chars >> 4];
				charsPointer[2] = table[*chars & 0xF];
				charsPointer += 3;
				break;
			default:
				*charsPointer = *chars;
				charsPointer++;
				break;
		}
		
		chars++;
	}
	*charsPointer = 0;
	
	NSString *encodedString = [NSString stringWithUTF8String:newChars];
	free(newChars);
	return encodedString;
}




- (void)dealloc {
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	
	[signerKeys release];
	[comments release];
	[signatures release];
	[keyserver release];
	[gpgHome release];
	[userInfo release];
	[lastSignature release];
	[_pinentryInfo release];	
	[asyncProxy release];
	[identifier release];
	[error release];
	[lastReturnValue release];
	[proxyServer release];
	[undoManager release];
	[gpgKeyservers release];
	[forceFilename release];
	[filename release];
	[gpgTask release];
	
	[super dealloc];
}


+ (NSSet *)algorithmSetFromString:(NSString *)string {
	NSMutableSet *algorithm = [NSMutableSet set];
	NSScanner *scanner = [NSScanner scannerWithString:string];
	scanner.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString:@";"];
	NSInteger value;
	
	while ([scanner scanInteger:&value]) {
		[algorithm addObject:[NSNumber numberWithInteger:value]];
	}
	return [[algorithm copy] autorelease];
}


+ (GPGErrorCode)testGPG {
	gpgConfigReaded = NO;
	return [self readGPGConfig];
}
+ (GPGErrorCode)testGPGError:(NSException **)error {
	gpgConfigReaded = NO;
	return [self readGPGConfigError:error];
}

+ (GPGErrorCode)readGPGConfig {
	return [self readGPGConfigError:nil];
}
+ (GPGErrorCode)readGPGConfigError:(NSException **)error {
	if (gpgConfigReaded) {
		return GPGErrorNoError;
	}
	
	@try {
		GPGTask *gpgTask = [GPGTask gpgTask];
		// Should return as quick as possible if the xpc helper is not available.
		gpgTask.timeout = GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY;
		[gpgTask addArgument:@"--list-config"];
		
		
		
		
		if ([gpgTask start] != 0) {
			GPGTask *gpgTask2 = [GPGTask gpgTaskWithArguments:@[@"--options", @"/dev/null", @"--gpgconf-test"]];
			gpgTask2.timeout = GPGTASKHELPER_DISPATCH_TIMEOUT_QUICKLY;
			
			// GPG could also return an error code if there is only an insignificant error. Like a missing keyring or so.
			// So we need to test explicit for a config error.
			if ([gpgTask2 start] != 0) { // Config Error.
				GPGOptions *options = [GPGOptions sharedOptions];
				[options repairGPGConf];
				
				if ([gpgTask start] != 0 && [gpgTask2 start] != 0) {
					GPGDebugLog(@"GPGController -readGPGConfig: GPGErrorConfigurationError");
					GPGDebugLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
					if (error) {
						*error = [GPGException exceptionWithReason:@"GPGErrorConfigurationError" errorCode:GPGErrorConfigurationError gpgTask:gpgTask];
					}
					return GPGErrorConfigurationError;
				}
			}
		}
		
		NSString *outText = [gpgTask outText];
		NSArray *lines = [outText componentsSeparatedByString:@"\n"];
		
		for (NSString *line in lines) {
			if ([line hasPrefix:@"cfg:"]) {
				NSArray *parts = [line componentsSeparatedByString:@":"];
				if ([parts count] > 2) {
					NSString *name = [parts objectAtIndex:1];
					NSString *value = [parts objectAtIndex:2];
					
					if ([name isEqualToString:@"version"]) {
						gpgVersion = [value retain];
					} else if ([name isEqualToString:@"pubkey"]) {
						publicKeyAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"cipher"]) {
						cipherAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"digest"]) {
						digestAlgorithm = [[self algorithmSetFromString:value] retain];
					} else if ([name isEqualToString:@"compress"]) {
						compressAlgorithm = [[self algorithmSetFromString:value] retain];
					}
				}
			}
		}
		
		if (!gpgVersion) {
			GPGDebugLog(@"GPGController -readGPGConfig: GPGErrorGeneralError");
			GPGDebugLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
			if (error) {
				*error = [GPGException exceptionWithReason:@"GPGErrorGeneralError" errorCode:GPGErrorGeneralError gpgTask:gpgTask];
			}
			return GPGErrorGeneralError;
		}
	} @catch (GPGException *exception) {
		GPGDebugLog(@"GPGController -readGPGConfig: %@", exception.description);
		GPGDebugLog(@"Error text: %@\nStatus text: %@", [exception gpgTask].errText, [exception gpgTask].statusText);
		if (exception.errorCode) {
			return exception.errorCode;
		} else {
			return GPGErrorGeneralError;
		}
	} @catch (NSException *exception) {
		GPGDebugLog(@"GPGController -readGPGConfig: %@", exception.description);
		return GPGErrorGeneralError;
	}
	
	gpgConfigReaded = YES;
	return GPGErrorNoError;
}


- (void)setLastReturnValue:(id)value {
	if (value != lastReturnValue) {
		[lastReturnValue release];
		lastReturnValue = [value retain];
	}
}

@end



