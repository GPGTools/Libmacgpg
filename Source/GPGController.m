/*
 Copyright © Roman Zechmeister, 2011
 
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

#import "GPGController.h"
#import "GPGKey.h"
#import "GPGTaskOrder.h"
#import "GPGRemoteKey.h"
#import "GPGSignature.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"
#import "GPGException.h"
#import "GPGPacket.h"
#import "GPGWatcher.h"
#import "GPGStream.h"
#import "GPGMemoryStream.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>


#define cancelCheck if (canceled) {@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Operation cancelled") errorCode:GPGErrorCancelled];}




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
+ (GPGErrorCode)readGPGConfig;
- (void)setLastReturnValue:(id)value;
- (void)restoreKeys:(NSObject <EnumerationList> *)keys withData:(NSData *)data;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName;
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName;
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys;
- (void)logException:(NSException *)e;
@end


@implementation GPGController
@synthesize delegate, keyserver, keyserverTimeout, proxyServer, async, userInfo, useArmor, useTextMode, printVersion, useDefaultComments, trustAllKeys, signatures, lastSignature, gpgHome, verbose, autoKeyRetrieve, lastReturnValue, error, undoManager, hashAlgorithm, gpgTask;

NSString *gpgVersion = nil;
NSSet *publicKeyAlgorithm = nil, *cipherAlgorithm = nil, *digestAlgorithm = nil, *compressAlgorithm = nil;
BOOL gpgConfigReaded = NO;



+ (NSString *)gpgVersion {
	[self readGPGConfig];
	return [[gpgVersion retain] autorelease];
}
+ (NSSet *)publicKeyAlgorithm {
	[self readGPGConfig];
	return [[publicKeyAlgorithm retain] autorelease];
}
+ (NSSet *)cipherAlgorithm {
	[self readGPGConfig];
	return [[cipherAlgorithm retain] autorelease];
}
+ (NSSet *)digestAlgorithm {
	[self readGPGConfig];
	return [[digestAlgorithm retain] autorelease];
}
+ (NSSet *)compressAlgorithm {
	[self readGPGConfig];
	return [[compressAlgorithm retain] autorelease];
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
	
	[GPGWatcher activate];
	
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
	NSSet *secKeyFingerprints, *updatedKeys = nil;
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
		
		
		gpgTask = [GPGTask gpgTask];
		gpgTask.batchMode = YES;
		[self addArgumentsForOptions];
		[gpgTask addArgument:@"--list-secret-keys"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArguments:searchStrings];
		
		[gpgTask start];
		/*if ([gpgTask start] != 0) {
			if ([keyList count] == 0) { //TODO: Bessere Lösung um Probleme zu vermeiden, wenn ein nicht (mehr) vorhandener Schlüssel gelistet werden soll.
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"List secret keys failed!") gpgTask:gpgTask];
			}
		}*/
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
		
		if ([gpgTask start] != 0) {
			if ([keyList count] == 0) { //TODO: Bessere Lösung um Probleme zu vermeiden, wenn ein nicht (mehr) vorhandener Schlüssel gelistet werden soll.
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"List public keys failed!") gpgTask:gpgTask];
			}
		}

		
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
		[updatedKeys autorelease];

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

    GPGMemoryStream *output = [GPGMemoryStream memoryStream];
    GPGMemoryStream *input = [GPGMemoryStream memoryStreamForReading:data];

    [self operationDidStart];
    [self processTo:output data:input withEncryptSignMode:mode recipients:recipients hiddenRecipients:hiddenRecipients];
	NSData *retVal = [output readAllData];
	[self cleanAfterOperation];
	[self operationDidFinishWithReturnValue:retVal];	
	return retVal;
}

- (void)processTo:(GPGStream *)output data:(GPGStream *)input withEncryptSignMode:(GPGEncryptSignMode)mode recipients:(NSObject<EnumerationList> *)recipients hiddenRecipients:(NSObject<EnumerationList> *)hiddenRecipients
{
    // asyncProxy not recognized here

	@try {		
		if ((mode & (GPGEncryptFlags | GPGSignFlags)) == 0) {
			[NSException raise:NSInvalidArgumentException format:@"Unknown mode: %i!", mode];
		}
		
		
		GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
		gpgTask = [GPGTask gpgTask];
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
			[gpgTask release];
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

		gpgTask.outStream = output;
		[gpgTask addInput:input];

		if ([gpgTask start] != 0) {
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

- (void)decryptTo:(GPGStream *)output data:(GPGStream *)input
{
	@try {
		NSData *unarmored = [GPGPacket unArmorFrom:input clearText:nil];
        if (unarmored) {
            input = [GPGMemoryStream memoryStreamForReading:unarmored];
        }
        else {
            [input seekToBeginning];
        }
		
		gpgTask = [GPGTask gpgTask];
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

- (NSArray *)verifySignatureOf:(GPGStream *)signatureInput originalData:(GPGStream *)originalInput
{
	NSArray *retVal;
	@try {
		[self operationDidStart];

		NSData *originalData = nil;		
		NSData *unarmored = [GPGPacket unArmorFrom:signatureInput clearText:originalInput ? nil : &originalData];
        if (unarmored) {
            signatureInput = [GPGMemoryStream memoryStreamForReading:unarmored];
        }
        else {
            [signatureInput seekToBeginning];
        }

        if (originalData)
            originalInput = [GPGMemoryStream memoryStreamForReading:originalData];
		
		
		gpgTask = [GPGTask gpgTask];
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
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(NSInteger)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(NSInteger)subkeyLength 
				  daysToExpire:(NSInteger)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy generateNewKeyWithName:name email:email comment:comment 
								   keyType:keyType keyLength:keyLength subkeyType:subkeyType subkeyLength:subkeyLength 
							  daysToExpire:daysToExpire preferences:preferences passphrase:passphrase];
		return nil;
	}
	NSString *fingerprint = nil;
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
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Generate new key failed!") gpgTask:gpgTask];
		}
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
			
			[self keyChanged:fingerprint];
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
		
		
		gpgTask = [GPGTask gpgTask];
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

- (void)cleanKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy cleanKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_CleanKey"];
		
		
		gpgTask = [GPGTask gpgTask];
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

- (void)minimizeKey:(NSObject <KeyFingerprint> *)key {
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy minimizeKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_MinimizeKey"];
		
		gpgTask = [GPGTask gpgTask];
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
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"-a"];
		[gpgTask addArgument:@"--gen-revoke"];
		[gpgTask addArgument:[key description]];
		
		if ([gpgTask start] != 0) {
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
		
		
		gpgTask = [GPGTask gpgTask];
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
		[order addCmd:@"passwd\n" prompt:@"keyedit.prompt"];
		[order addCmd:@"save\n" prompt:@"keyedit.prompt"];
		
		
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		gpgTask.userInfo = [NSDictionary dictionaryWithObject:order forKey:@"order"]; 
		[gpgTask addArgument:@"--edit-key"];
		[gpgTask addArgument:[key description]];
		
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
			NSInteger uid = [self indexOfUserID:hashID fromKey:key];
			
			if (uid <= 0) {
				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"UserID not found!") userInfo:[NSDictionary dictionaryWithObjectsAndKeys:hashID, @"hashID", key, @"key", nil] errorCode:GPGErrorNoUserID gpgTask:nil];
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
		
		gpgTask = [GPGTask gpgTask];
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

- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust {
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
		
		
		gpgTask = [GPGTask gpgTask];
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


#pragma mark Import and export

- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport {
	NSString *statusText = nil;
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy importFromData:data fullImport:fullImport];
		return nil;
	}
	@try {
		data = [GPGPacket unArmor:data];
		NSSet *keys = [self keysInExportedData:data];
		
		if ([keys count] == 0) {
			//Get keys from RTF data.
			NSData *data2 = [[[[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:nil error:nil] autorelease] string] dataUsingEncoding:NSUTF8StringEncoding];
			if (data2) {
				data2 = [GPGPacket unArmor:data2];
				keys = [self keysInExportedData:data2];
				if ([keys count] > 0) {
					data = data2;
				}
			}
		}
		
		//TODO: Uncomment the following lines when keysInExportedData: fully works!
		/*if ([keys count] == 0) {
			[NSException raise:NSInvalidArgumentException format:@"No keys to import!"];
		}*/
		
		
		[self operationDidStart];
		[self registerUndoForKeys:keys withName:@"Undo_Import"];
		

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

- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport {
	NSData *exportedData = nil;
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
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Export failed!") gpgTask:gpgTask];
		}
		exportedData = [gpgTask outData];
		
		
		if (allowSec) {
			[arguments replaceObjectAtIndex:0 withObject:@"--export-secret-keys"];
			gpgTask = [GPGTask gpgTask];
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


#pragma mark Working with Signatures

- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire {
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

- (void)removeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy removeSignature:signature fromUserID:userID ofKey:key];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RemoveSignature"];

		NSInteger uid = [self indexOfUserID:userID.hashID fromKey:key];
		
		if (uid > 0) {
			GPGTaskOrder *order = [GPGTaskOrder orderWithNoToAll];
			[order addCmd:[NSString stringWithFormat:@"uid %i\n", uid] prompt:@"keyedit.prompt"];
			[order addCmd:@"delsig\n" prompt:@"keyedit.prompt"];
			
			NSArray *userIDsignatures = userID.signatures;
			for (GPGKeySignature *aSignature in userIDsignatures) {
				if (aSignature == signature) {
					[order addCmd:@"y\n" prompt:@"keyedit.delsig.valid"];
					if ([[signature keyID] isEqualToString:[key.description keyID]]) {
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

- (void)revokeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description { //Diese Funktion ist äusserst ineffizient, mir ist allerdings kein besserer Weg bekannt.
	if (async && !asyncStarted) {
		asyncStarted = YES;
		[asyncProxy revokeSignature:signature fromUserID:userID ofKey:key reason:reason description:description];
		return;
	}
	@try {
		[self operationDidStart];
		[self registerUndoForKey:key withName:@"Undo_RevokeSignature"];

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
		
		
		gpgTask = [GPGTask gpgTask];
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
		
		
		gpgTask = [GPGTask gpgTask];
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
		
		gpgTask = [GPGTask gpgTask];
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
		
		gpgTask = [GPGTask gpgTask];
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
		gpgTask = [GPGTask gpgTask];
		[self addArgumentsForOptions];
		[self addArgumentsForKeyserver];
		[gpgTask addArgument:@"--recv-keys"];
		for (id key in keys) {
			[gpgTask addArgument:[key description]];
		}
		
		if ([gpgTask start] != 0) {
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Receive keys failed!") gpgTask:gpgTask];
		}
		
		NSSet *changedKeys = fingerprintsFromStatusText(gpgTask.statusText);
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
		gpgTask = [GPGTask gpgTask];
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
		
		gpgTask = [GPGTask gpgTask];
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
				GPGDebugLog(@"No OK from gpg-agent.");
				goto closeSocket;
			}
			NSString *command = [NSString stringWithFormat:@"GET_PASSPHRASE --no-ask %@ . . .\n", key];
			send(sock, [command UTF8String], [command UTF8Length], 0);
			
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
	gpgTask = [GPGTask gpgTask];
	[self addArgumentsForOptions];
	[gpgTask addArgument:@"-k"];
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

- (NSSet *)keysInExportedData:(NSData *)data {
	NSMutableSet *keys = [NSMutableSet set];
	NSArray *packets = [GPGPacket packetsWithData:data];
	
	for (GPGPacket *packet in packets) {
		if (packet.type == GPGPublicKeyPacket || packet.type == GPGSecretKeyPacket) {
			[keys addObject:packet.fingerprint];
		}
	}
	
	return keys;
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
		gpgTask = nil;
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
		lastReturnValue = value;
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
	BOOL oldAsny = self.async;
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
	
	self.async = oldAsny;
	groupedKeyChange--;
	[self keysChanged:keys];
	[undoManager enableUndoRegistration];
}

- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys withName:(NSString *)actionName {
	if ([undoManager isUndoRegistrationEnabled]) {
		BOOL oldAsny = self.async;
		self.async = NO;
		if ([NSThread isMainThread]) {
			[self registerUndoForKeys:keys];
		} else {
			[self performSelectorOnMainThread:@selector(registerUndoForKeys:) withObject:keys waitUntilDone:YES];
		}
		self.async = oldAsny;
		
		if (actionName && ![undoManager isUndoing] && ![undoManager isRedoing]) {
			[undoManager setActionName:localizedLibmacgpgString(actionName)];
		}
	}
}
- (void)registerUndoForKey:(NSObject <KeyFingerprint> *)key withName:(NSString *)actionName {
	[self registerUndoForKeys:[NSSet setWithObject:key] withName:actionName];
}
- (void)registerUndoForKeys:(NSObject <EnumerationList> *)keys {
	GPGTask *oldGPGTask = gpgTask;
	[[undoManager prepareWithInvocationTarget:self] restoreKeys:keys withData:[self exportKeys:keys allowSecret:YES fullExport:YES]];
	gpgTask = oldGPGTask;
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
	gpgTask.delegate = self;
	if ([delegate respondsToSelector:@selector(gpgController:progressed:total:)]) {
		gpgTask.progressInfo = YES;
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
	
	*updatedKeys = [updatedKeysSet copy]; // copy without autorelease!
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


+ (GPGErrorCode)testGPG {
	gpgConfigReaded = NO;
	return [self readGPGConfig];
}

+ (GPGErrorCode)readGPGConfig {
	if (gpgConfigReaded) {
		return GPGErrorNoError;
	}
	
	@try {
		GPGTask *gpgTask = [GPGTask gpgTask];
		[gpgTask addArgument:@"--list-config"];
		
		if ([gpgTask start] != 0) {
			GPGDebugLog(@"GPGController -readGPGConfig: GPGErrorConfigurationError");
			GPGDebugLog(@"Error text: %@\nStatus text: %@", gpgTask.errText, gpgTask.statusText);
			return GPGErrorConfigurationError;
		}
		
		NSString *outText = [gpgTask outText];
		if (!outText || outText.length < 10) {
			return GPGErrorGeneralError;
		}
		
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



