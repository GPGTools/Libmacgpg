#import <Cocoa/Cocoa.h>
#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGKey.h>
#import <Libmacgpg/GPGTask.h>

@class GPGSignature;
@class GPGController;

@protocol GPGControllerDelegate
@optional

- (void)gpgController:(GPGController *)gpgc operationDidFinishWithReturnValue:(id)value;
- (void)gpgController:(GPGController *)gpgc operationDidFailWithException:(NSException *)e;
- (void)gpgController:(GPGController *)gpgc keysDidChangedExernal:(NSObject <EnumerationList> *)keys;
- (void)gpgControllerOperationWillStart:(GPGController *)gpgc;


@end



@interface GPGController : NSObject <GPGTaskDelegate> {
	NSMutableArray *signerKeys;
	NSMutableArray *comments;
	NSMutableArray *signatures;
	NSString *keyserver;
	NSUInteger keyserverTimeout;
	NSString *proxyServer;
	NSString *gpgHome;
	NSDictionary *userInfo;
	BOOL useArmor;
	BOOL useTextMode;
	BOOL printVersion;
	BOOL useDefaultComments;
	BOOL trustAllKeys;
	BOOL async;
    BOOL verbose;
	
	NSObject <GPGControllerDelegate> *delegate;
	

	
	//Private
	NSString *identifier;
	id asyncProxy; //AsyncProxy
	GPGSignature *lastSignature;
	GPGTask *gpgTask;
	BOOL asyncStarted;
	BOOL canceled;
	NSInteger runningOperations;
}

@property (assign) NSObject <GPGControllerDelegate> *delegate;
@property (readonly) NSArray *signerKeys;
@property (readonly) NSArray *comments;
@property (readonly) NSArray *signatures;
@property (retain) NSString *keyserver;
@property (retain) NSString *proxyServer;
@property (retain) NSString *gpgHome;
@property NSUInteger keyserverTimeout;
@property (retain) NSDictionary *userInfo;
@property BOOL async;
@property BOOL useArmor;
@property BOOL useTextMode;
@property BOOL printVersion;
@property BOOL useDefaultComments;
@property BOOL trustAllKeys;
@property BOOL verbose;


+ (NSString *)gpgVersion;
+ (NSSet *)publicKeyAlgorithm;
+ (NSSet *)cipherAlgorithm;
+ (NSSet *)digestAlgorithm;
+ (NSSet *)compressAlgorithm;


- (void)addComment:(NSString *)comment;
- (void)removeCommentAtIndex:(NSUInteger)index;
- (void)addSignerKey:(NSString *)signerKey;
- (void)removeSignerKeyAtIndex:(NSUInteger)index;


+ (id)gpgController;
+ (void)colonListing:(NSString *)colonListing toArray:(NSArray **)array andFingerprints:(NSArray **)fingerprints;
+ (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing;
- (BOOL)isPassphraseForKeyInCache:(NSObject <KeyFingerprint> *)key;
- (BOOL)isPassphraseForKeyInGPGAgentCache:(NSObject <KeyFingerprint> *)key;
- (BOOL)isPassphraseForKeyInKeychain:(NSObject <KeyFingerprint> *)key;
- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key;
- (NSInteger)indexOfSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key;


- (NSSet *)allKeys;
- (NSSet *)allSecretKeys;
- (NSSet *)keysForSearchPattern:(NSString *)searchPattern;
- (NSSet *)keysForSearchPatterns:(NSObject <EnumerationList> *)searchPatterns;
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList;
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList withSigs:(BOOL)withSigs;
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList searchFor:(NSObject <EnumerationList> *)serachList withSigs:(BOOL)withSigs;
- (NSSet *)updateKeys:(NSObject <EnumerationList> *)keyList searchFor:(NSObject <EnumerationList> *)serachList withSigs:(BOOL)withSigs secretOnly:(BOOL)secretOnly;

- (void)cancel;

- (void)cleanKey:(NSObject <KeyFingerprint> *)key;
- (void)minimizeKey:(NSObject <KeyFingerprint> *)key;
- (void)addPhotoFromPath:(NSString *)path toKey:(NSObject <KeyFingerprint> *)key;
- (void)removeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeUserID:(NSString *)hashID fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport;
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport;
- (NSData *)genRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire;
- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addUserIDToKey:(NSObject <KeyFingerprint> *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment;
- (void)setExpirationDateForSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key daysToExpire:(NSInteger)daysToExpire;
- (void)changePassphraseForKey:(NSObject <KeyFingerprint> *)key;
- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys;
- (void)removeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)setPrimaryUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(NSInteger)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(NSInteger)subkeyLength 
				  daysToExpire:(NSInteger)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase;
- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode;
- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (NSArray *)searchKeysOnServer:(NSString *)pattern;
- (void)revokeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)key:(NSObject <KeyFingerprint> *)key setDisabled:(BOOL)disabled;
- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust;

- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients;
- (NSData *)decryptData:(NSData *)data;
- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData;
- (NSArray *)verifySignedData:(NSData *)signedData;





@end


