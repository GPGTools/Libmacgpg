#import "GPGController.h"
#import "GPGKey.h"
#import "GPGTaskOrder.h"
#import "GPGRemoteKey.h"
#import "GPGSignature.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"


#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>


#define cancelCheck if (canceled) {@throw gpgException(GPGException, @"Operation cancelled", GPGErrorCancelled);}

#define setValueWithoutSetter(var, value) do { \
		id temp = (value); \
		if (temp != var) { \
			[var release]; \
			var = temp; \
		} \
	} while (0);





@interface GPGController ()
@property (retain) GPGSignature *lastSignature;
- (void)updateKeysWithDict:(NSDictionary *)aDict;
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
+ (void)readGPGConfig;
@end


@implementation GPGController
@synthesize delegate, keyserver, keyserverTimeout, proxyServer, async, userInfo, useArmor, useTextMode, printVersion, useDefaultComments, trustAllKeys, signatures, lastSignature, gpgHome, verbose, error;

NSString *gpgVersion = nil;
NSSet *publicKeyAlgorithm = nil, *cipherAlgorithm = nil, *digestAlgorithm = nil, *compressAlgorithm = nil;



+ (NSString *)gpgVersion {
	if (!gpgVersion) {
		[self readGPGConfig];
	}
	return [[gpgVersion retain] autorelease];
}
+ (NSSet *)publicKeyAlgorithm {
	if (!publicKeyAlgorithm) {
		[self readGPGConfig];
	}
	return [[publicKeyAlgorithm retain] autorelease];
}
+ (NSSet *)cipherAlgorithm {
	if (!cipherAlgorithm) {
		[self readGPGConfig];
	}
	return [[cipherAlgorithm retain] autorelease];
}
+ (NSSet *)digestAlgorithm {
	if (!digestAlgorithm) {
		[self readGPGConfig];
	}
	return [[digestAlgorithm retain] autorelease];
}
+ (NSSet *)compressAlgorithm {
	if (!compressAlgorithm) {
		[self readGPGConfig];
	}
	return [[compressAlgorithm retain] autorelease];
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
- (void)setSignerKey:(NSString *)signerKey {
	[self willChangeValueForKey:@"signerKeys"];
	[signerKeys removeAllObjects];
	if (signerKey) {
		[signerKeys addObject:signerKey];
	}
	[self didChangeValueForKey:@"signerKeys"];
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
	keyserverTimeout = 10;
	asyncProxy = [[AsyncProxy alloc] initWithRealObject:self];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysHaveChanged:) name:GPGKeysChangedNotification object:nil];
	
	return self;
}



- (void)cancel {
	canceled = YES;
	if (gpgTask.isRunning) {
		[gpgTask cancel];
	}
}



#pragma mark Search and update keys

- (NSSet *)allKeys {
	return [self updateKeys:nil searchFor:nil withSigs:NO secretOnly:NO];
}
- (NSSet *)allSecretKeys {
	return [self updateKeys:nil searchFor:nil withSigs:NO secretOnly:YES];
}
- (NSSet *)keysForSearchPattern:(NSString *)searchPattern {
	return [self updateKeys:nil searchFor:[NSSet setWithObject:searchPattern] withSigs:NO secretOnly:NO];
}
- (NSSet *)keysForSearchPatterns:(NSObject <EnumerationList> *)searchPatterns {
	return [self updateKeys:nil searchFor:searchPatterns withSigs:NO secretOnly:NO];
}
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList {
	return [self updateKeys:keyList searchFor:keyList withSigs:[keyList count] < 5 secretOnly:NO];
}
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList withSigs:(BOOL)withSigs {
	return [self updateKeys:keyList searchFor:keyList withSigs:withSigs secretOnly:NO];
}
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList searchFor:(NSObject <EnumerationList> *)serachList withSigs:(BOOL)withSigs {
	return [self updateKeys:keyList searchFor:serachList withSigs:withSigs secretOnly:NO];
}
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList searchFor:(NSObject <EnumerationList> *)serachList withSigs:(BOOL)withSigs secretOnly:(BOOL)secretOnly {
	NSSet *secKeyFingerprints, *updatedKeys;
	NSArray *fingerprints, *listings;
	
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy updateKeys:keyList searchFor:serachList withSigs:withSigs];
		return nil;
	}
	@try {
		[self operationDidStart];
		
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
				cancelCheck;
				[searchSet addObject:[item description]];
			}
			searchStrings = [searchSet allObjects];
		}
		
		//=========================================================================================
		//=========================================================================================
		//=========================================================================================
		
		
		
		/*NSTimeInterval t[10];
		int i = 0;
		t[i++] = [NSDate timeIntervalSinceReferenceDate];
		*/
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--list-secret-keys"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:searchStrings];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"List secret keys failed!", GPGErrorTaskException, gpgTask);
		}
		secKeyFingerprints = [[self class] fingerprintsFromColonListing:gpgTask.outText];

		
		if (secretOnly) {
			searchStrings = [secKeyFingerprints allObjects];
		}

		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		if (withSigs) {
			[gpgTask addArgument:@"--list-sigs"];
			[gpgTask addArgument:@"--list-options"];
			[gpgTask addArgument:@"show-sig-subpackets=29"];
		} else {
			[gpgTask addArgument:@"--list-keys"];
		}
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:searchStrings];
		
		//t[i++] = [NSDate timeIntervalSinceReferenceDate];
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"List public keys failed!", GPGErrorTaskException, gpgTask);
		}
		//t[i++] = [NSDate timeIntervalSinceReferenceDate];
		[[self class] colonListing:gpgTask.outText toArray:&listings andFingerprints:&fingerprints];
		
		
		
		NSDictionary *argumentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											listings, @"listings", 
											fingerprints, @"fingerprints", 
											secKeyFingerprints, @"secKeyFingerprints", 
											keyList, @"keysToUpdate",
											[NSValue valueWithPointer:&updatedKeys], @"updatedKeys",
											[NSNumber numberWithBool:withSigs], @"withSigs", nil];
		
		cancelCheck;
		
		if ([NSThread isMainThread]) {
			[self updateKeysWithDict:argumentDictionary];
		} else {
			[self performSelectorOnMainThread:@selector(updateKeysWithDict:) withObject:argumentDictionary waitUntilDone:YES];
		}
		
		
		/*t[i++] = [NSDate timeIntervalSinceReferenceDate];
		for (int j = 0; j+1<i; j++) {
			NSLog(@"Zeit%i-%i: %f", j, j+1, t[j+1] - t[j]);
		}*/
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:updatedKeys];	
	return updatedKeys;
}



#pragma mark Encrypt, decrypt, sign and verify



- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy processData:data withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		if ((mode & (GPGEncryptFlags | GPGSignFlags)) == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Unknwon mode: %i!", mode];
		}
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		gpgTask.batchMode = NO;
        gpgTask.verbose = self.verbose;
		
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
			GPGTask *tempTask = gpgTask;
			data = [self processData:data withEncryptSignMode:mode & ~(GPGEncryptFlags | GPGSeparateSign) recipients:nil hiddenRecipients:nil];
			gpgTask = tempTask;
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


		[gpgTask addInData:data];

		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Process data failed!", GPGErrorTaskException, gpgTask);
		}		
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	NSData *retVal = gpgTask.outData;
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
	
}

- (NSData *)decryptData:(NSData *)data {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy decryptData:data];
		return nil;
	}
    
	@try {
		[self operationDidStart];
		
		
		gpgTask = [GPGTask gpgTask];
        gpgTask.verbose = YES;
		[self addArgumentsForOptions];
		[gpgTask addInData:data];
		
		[gpgTask addArgument:@"--decrypt"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Decrypt failed!", GPGErrorTaskException, gpgTask);
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}

    NSData *retVal = gpgTask.outData;
    
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy verifySignature:signatureData originalData:originalData];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addInData:signatureData];
		if (originalData) {
			[gpgTask addInData:originalData];
		}
		
		[gpgTask addArgument:@"--verify"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Verify failed!", GPGErrorTaskException, gpgTask);
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	NSArray *retVal = self.signatures;
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (NSArray *)verifySignedData:(NSData *)signedData {
	return [self verifySignature:signedData originalData:nil];
}




#pragma mark Edit keys

- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(NSInteger)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(NSInteger)subkeyLength 
				  daysToExpire:(NSInteger)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateNewKeyWithName:name email:email comment:comment 
								   keyType:keyType keyLength:keyLength subkeyType:subkeyType subkeyLength:subkeyLength 
							  daysToExpire:daysToExpire preferences:preferences passphrase:passphrase];
		return;
	}
	@try {
		[self operationDidStart];
		
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
		[self addArgumentsForOptions];
		gpgTask.batchMode = YES;
		[gpgTask addInText:cmdText];
		
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Generate new key failed!", GPGErrorTaskException, gpgTask);
		}
		[self keysChanged:nil];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy deleteKeys:keys withMode:mode];
		return;
	}
	@try {
		[self operationDidStart];
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		
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
			@throw gpgTaskException(GPGTaskException, @"Set primary userID failed!", GPGErrorTaskException, gpgTask);
		}
		[self keysChanged:keys];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
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
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"clean"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Clean failed!", GPGErrorTaskException, gpgTask);
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
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
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"minimize"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Minimize failed!", GPGErrorTaskException, gpgTask);
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (NSData *)genRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy genRevokeCertificateForKey:key reason:reason description:description];
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
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"-a"];
		[gpgTask addArgument:@"--gen-revoke"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Generate revoke certificate failed!", GPGErrorTaskException, gpgTask);
		}
		
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:gpgTask.outData];	
	return gpgTask.outData;
}

- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		
		NSData *revocationData = [self genRevokeCertificateForKey:key reason:reason description:description];
		[self importFromData:revocationData fullImport:YES];
		
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
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		if (subkey) {
			int index = [self indexOfSubkey:subkey fromKey:key];
			if (index > 0) {
				[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
			} else {
				@throw gpgExceptionWithUserInfo(GPGException, @"Subkey not found!", GPGErrorSubkeyNotFound, [NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]);
			}
		}
		
		[order addCmd:@"expire\n" prompt:@"keyedit.prompt"];
		[order addInt:daysToExpire prompt:@"keygen.valid"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Add userID failed!", GPGErrorTaskException, gpgTask);
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
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"passwd\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Change passphrase failed!", GPGErrorTaskException, gpgTask);
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy setAlgorithmPreferences:preferences forUserID:hashID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		if (hashID) {
			NSInteger uid = [self indexOfUserID:hashID fromKey:key];
			
			if (uid <= 0) {
				@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]);
			}
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
		}
		[order addCmd:[NSString stringWithFormat:@"setpref %@\n", preferences] prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Set preferences failed!", GPGErrorTaskException, gpgTask);
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
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:disabled ? @"disable" : @"enable"];
		[gpgTask addArgument:@"quit"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, disabled ? @"Disable key failed!" : @"Enable key failed!", GPGErrorTaskException, gpgTask);
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
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy key:key setOwnerTrsut:trust];
		return;
	}
	@try {
		[self operationDidStart];
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"trust\n" prompt:@"keyedit.prompt"];
		[order addInt:trust prompt:@"edit_ownertrust.value"];
		[order addCmd:@"quit\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Set trust failed!", GPGErrorTaskException, gpgTask);
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Import and export

- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport {
	NSString *statusText;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy importFromData:data fullImport:fullImport];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[gpgTask addInData:data];
		[gpgTask addArgument:@"--import"];
		if (fullImport) {
			[gpgTask addArgument:@"--import-options"];
			[gpgTask addArgument:@"import-local-sigs"];
			[gpgTask addArgument:@"--allow-non-selfsigned-uid"];
		}
		
		
		[gpgTask start];
		
		statusText = gpgTask.statusText;
		//TODO: Better error detection!
		if ([statusText rangeOfString:@"[GNUPG:] IMPORT_OK "].length <= 0) {
			@throw gpgTaskException(GPGTaskException, @"Import failed!", GPGErrorTaskException, gpgTask);
		}
		[self keysChanged:nil]; //TODO: Identify imported keys.
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:statusText];	
	return statusText;
}

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	NSData *exportedData;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy exportKeys:keys allowSecret:allowSec fullExport:fullExport];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
		[arguments addObject:@"--export"];
		
		if (fullExport) {
			[arguments addObject:@"--export-options"];
			[arguments addObject:@"export-local-sigs,export-sensitive-revkeys"];
		}
		for (NSObject <KeyFingerprint> * key in keys) {
			[arguments addObject:[key description]];
		}
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForComments];
		[gpgTask addArguments:arguments];
		
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Export failed!", GPGErrorTaskException, gpgTask);
		}
		exportedData = gpgTask.outData;
		
		
		if (allowSec) {
			[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
			gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[self addArgumentsForComments];
			[gpgTask addArguments:arguments];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Export failed!", GPGErrorTaskException, gpgTask);
			}
			exportedData = [NSMutableData dataWithData:exportedData];
			[(NSMutableData *)exportedData appendData:gpgTask.outData];
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:exportedData];	
	return exportedData;
}


#pragma mark Working with Signatures

- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy signUserID:hashID ofKey:key signKey:signKey type:type local:local daysToExpire:daysToExpire];
		return;
	}
	@try {
		NSString *uid;
		if (!hashID) {
			uid = @"uid *\n";
		} else {
			int uidIndex = [self indexOfUserID:hashID fromKey:key];
			if (uidIndex > 0) {
				uid = [NSString stringWithFormat:@"uid %i\n", uidIndex];
			} else {
				@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]);
			}
		}
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:uid prompt:@"keyedit.prompt"];
		[order addCmd:local ? @"lsign\n" : @"sign\n" prompt:@"keyedit.prompt"];
		[order addCmd:[NSString stringWithFormat:@"%i\n", daysToExpire] prompt:@"siggen.valid" optional:YES];
		[order addCmd:[NSString stringWithFormat:@"%i\n", type] prompt:@"sign_uid.class" optional:YES];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
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
			@throw gpgTaskException(GPGTaskException, @"Sign userID failed!", GPGErrorTaskException, gpgTask);
		}
		[self keyChanged:key];
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)revokeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSignature:signature fromUserID:userID ofKey:key reason:reason description:description];
		return;
	}
	@try {
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
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Revoke signature failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil]);
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)removeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSignature:signature fromUserID:userID ofKey:key];
		return;
	}
	@try {
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
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Remove signature failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:userID.hashID, @"hashID", key, @"key", nil]);
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}


#pragma mark Working with Subkeys

- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSubkey:subkey fromKey:key];
		return;
	}
	@try {
		NSInteger index = [self indexOfSubkey:subkey fromKey:key];
		
		if (index > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"key %i\n", index] prompt:@"keyedit.prompt"];
			[order addCmd:@"delkey\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Remove subkey failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"Subkey not found!", GPGErrorSubkeyNotFound, [NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]);
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
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Revoke subkey failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"Subkey not found!", GPGErrorSubkeyNotFound, [NSDictionary dictionaryWithObjectsAndKeys:subkey, @"subkey", key, @"key", nil]);
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	
	[self operationDidFinishWithReturnValue:nil];	
}

- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy addSubkeyToKey:key type:type length:length daysToExpire:daysToExpire];
		return;
	}
	@try {
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"addkey\n" prompt:@"keyedit.prompt"];
		[order addInt:type prompt:@"keygen.algo"];
		[order addInt:length prompt:@"keygen.size"];
		[order addInt:daysToExpire prompt:@"keygen.valid"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Add subkey failed!", GPGErrorTaskException, gpgTask);
		}
		NSLog(@"\nOut: %@\nErr: %@", gpgTask.outText, gpgTask.errText);
		[self keyChanged:key];
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
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		[order addCmd:@"adduid\n" prompt:@"keyedit.prompt"];
		[order addCmd:name prompt:@"keygen.name"];
		[order addCmd:email prompt:@"keygen.email"];
		[order addCmd:comment prompt:@"keygen.comment"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Add userID failed!", GPGErrorTaskException, gpgTask);
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
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"deluid\n" prompt:@"keyedit.prompt"];
			[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
			
			gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Remove userID failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]);
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
			[self addArgumentsForOptions];
			gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Revoke userID failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]);
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
		NSInteger uid = [self indexOfUserID:hashID fromKey:key];
		
		if (uid > 0) {
			gpgTask = [GPGTask gpgTask];
			[self addArgumentsForOptions];
			[gpgTask addArgument:@"--edit-key"];
			[gpgTask addArgument:[key description]];
			[gpgTask addArgument:[NSString stringWithFormat:@"%i", uid]];
			[gpgTask addArgument:@"primary"];
			[gpgTask addArgument:@"save"];
			
			if ([gpgTask start] != 0) {
				@throw gpgTaskException(GPGTaskException, @"Set primary userID failed!", GPGErrorTaskException, gpgTask);
			}
			[self keyChanged:key];
		} else {
			@throw gpgExceptionWithUserInfo(GPGException, @"UserID not found!", GPGErrorNoUserID, [NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil]);
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
		GPGTaskOrder *order = [GPGTaskOrder orderWithYesToAll];
		
		[order addCmd:path prompt:@"photoid.jpeg.add"];
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		[gpgTask addArgument:@"addphoto"];
		[gpgTask addArgument:@"save"];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Add photo failed!", GPGErrorTaskException, gpgTask);
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
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--refresh-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Refresh keys failed!", GPGErrorTaskException, gpgTask);
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
		
		if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Empty key list!"];
		}
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--recv-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Receive keys failed!", GPGErrorTaskException, gpgTask);
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
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--send-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Receive keys failed!", GPGErrorTaskException, gpgTask);
		}
	} @catch (NSException *e) {
		[self handleException:e];
	} @finally {
		[self cleanAfterOperation];
	}
	[self operationDidFinishWithReturnValue:nil];	
}

- (NSArray *)searchKeysOnServer:(NSString *)pattern {
	NSArray *keys;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy searchKeysOnServer:pattern];
		return nil;
	}
	@try {
		[self operationDidStart];
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.batchMode = YES;
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--search-keys"];
		[gpgTask addArgument:@"--"];
		[gpgTask addArgument:pattern];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"Search keys failed!", GPGErrorTaskException, gpgTask);
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



#pragma mark Help methods

- (BOOL)isPassphraseForKeyInCache:(NSObject <KeyFingerprint> *)key {
	return [self isPassphraseForKeyInGPGAgentCache:key] || [self isPassphraseForKeyInKeychain:key];
}

- (BOOL)isPassphraseForKeyInKeychain:(NSObject <KeyFingerprint> *)key {
	NSString *fingerprint = [key description];
	return SecKeychainFindGenericPassword (nil, strlen(GPG_SERVICE_NAME), GPG_SERVICE_NAME, [fingerprint UTF8Length], [fingerprint UTF8String], nil, nil, nil) == 0; 
}

- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSObject <KeyFingerprint> *)key {
	NSString *socketPath = [GPGTask gpgAgentSocket];
	if (socketPath) {
		int sock;
		if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
			perror("socket");
			return NO;
		}

		int length = [socketPath UTF8Length] + 2;
		char addressInfo[length];
		addressInfo[0] = AF_UNIX;
		addressInfo[1] = 0;
		strcpy(addressInfo+2, [socketPath UTF8String]);
				
		
		if (connect(sock, (const struct sockaddr *)addressInfo, length ) == -1) {
			perror("connect");
			goto closeSocket;
		}
		
		
		struct timeval timeout;
		timeout.tv_usec = 0;
		timeout.tv_sec = 2;
		setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
		
		
		char buffer[100];
		if (recv(sock, buffer, 100, 0) > 2) {
			if (strncmp(buffer, "OK", 2)) {
				NSLog(@"No OK from gpg-agent.");
				goto closeSocket;
			}
			NSString *command = [NSString stringWithFormat:@"GET_PASSPHRASE --no-ask %@ . . .\n", key];
			length = send(sock, [command UTF8String], [command UTF8Length], 0);
			
			int pos = 0;
			while ((length = recv(sock, buffer+pos, 100-pos, 0)) > 0) {
				pos += length;
				if (strnstr(buffer, "OK", pos)) {
					return YES;
				} else if (strnstr(buffer, "ERR", pos)) {
					goto closeSocket;
				}
			}
		} else {
			return NO;
		}
	closeSocket:
		close(sock);
	}
	return NO;
}

- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key {
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw gpgTaskException(GPGTaskException, @"indexOfUserID failed!", GPGErrorTaskException, gpgTask);
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
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:@"--with-fingerprint"];
	[gpgTask addArgument:[key description]];
	
	if ([gpgTask start] != 0) {
		@throw gpgTaskException(GPGTaskException, @"indexOfSubkey failed!", GPGErrorTaskException, gpgTask);
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
			//no break!
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

- (void)gpgTaskDidStart:(GPGTask *)task {
	if ([signatures count] > 0) {
		self.lastSignature = nil;
		[signatures release];
		signatures = [[NSMutableArray alloc] init];	
	}
}



#pragma mark Notify delegate


- (void)handleException:(NSException *)e {
	if (asyncStarted && runningOperations == 1 && [delegate respondsToSelector:@selector(gpgController:operationThrownException:)]) {
		[delegate gpgController:self operationThrownException:e];
	}
	[e retain];
	[error release];
	error = e;
}

- (void)operationDidStart {
	if (runningOperations == 0) {
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
		if ([delegate respondsToSelector:@selector(gpgController:operationDidFinishWithReturnValue:)]) {
			[delegate gpgController:self operationDidFinishWithReturnValue:value];
		}		
	}
}

- (void)keysHaveChanged:(NSNotification *)notification {
	if (self != notification.object && ![identifier isEqualTo:notification.object] && [delegate respondsToSelector:@selector(gpgController:keysDidChangedExernal:)]) {
		NSDictionary *dictionary = notification.userInfo;
		NSObject <EnumerationList> *keys = [dictionary objectForKey:@"keys"];		
		if ([keys conformsToProtocol:@protocol(EnumerationList)]) {
			[delegate gpgController:self keysDidChangedExernal:keys];
		}
	}
}



#pragma mark Private


- (void)keysChanged:(NSObject <EnumerationList> *)keys {
	NSDictionary *dictionary = nil;
	if (keys) {
		NSMutableArray *fingerprints = [NSMutableArray arrayWithCapacity:[keys count]];
		for (NSObject *key in keys) {
			[fingerprints addObject:[key description]];
		}
		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:fingerprints, @"keys", nil];
	}
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:dictionary options:NSNotificationPostToAllSessions];
}
- (void)keyChanged:(NSObject <KeyFingerprint> *)key {
	if (key) {
		[self keysChanged:[NSSet setWithObject:key]];
	} else {
		[self keysChanged:nil];
	}
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
	[keyserverOptions appendFormat:@"timeout=%lu", keyserverTimeout];
	NSString *proxy = proxyServer ? proxyServer : [[GPGOptions sharedOptions] httpProxy];
	if ([proxy length] > 0) {
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
	gpgTask.delegate = self;
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
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
	
	[signerKeys release];
	[comments release];
	[signatures release];
	self.keyserver = nil;
	self.gpgHome = nil;
	self.userInfo = nil;
	self.lastSignature = nil;
	[asyncProxy release];
	[identifier release];
	
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

+ (void)readGPGConfig {
	GPGTask *gpgTask = [GPGTask gpgTask];
	[gpgTask addArgument:@"--list-config"];
	[gpgTask start];
	NSString *outText = [gpgTask outText];
	
	if (!outText || outText.length < 10) {
		NSLog(@"readGPGConfig faild");
		return;
	}
	
	NSArray *lines = [outText componentsSeparatedByString:@"\n"];
	
	for (NSString *line in lines) {
		if ([line hasPrefix:@"cfg:"]) {
			NSArray *parts = [line componentsSeparatedByString:@":"];
			if ([parts count] > 2) {
				NSString *name = [parts objectAtIndex:1];
				NSString *value = [parts objectAtIndex:2];
				
				if ([name isEqualToString:@"version"]) {
					setValueWithoutSetter(gpgVersion, value);
				} else if ([name isEqualToString:@"pubkey"]) {
					setValueWithoutSetter (publicKeyAlgorithm, [self algorithmSetFromString:value]);
				} else if ([name isEqualToString:@"cipher"]) {
					setValueWithoutSetter (cipherAlgorithm, [self algorithmSetFromString:value]);
				} else if ([name isEqualToString:@"digest"]) {
					setValueWithoutSetter (digestAlgorithm, [self algorithmSetFromString:value]);
				} else if ([name isEqualToString:@"compress"]) {
					setValueWithoutSetter (compressAlgorithm, [self algorithmSetFromString:value]);
				}
			}
		}
	}
}








@end



