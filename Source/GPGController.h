#import "GPGGlobals.h"
#import "GPGKey.h"
#import "GPGTask.h"

@class GPGSignature;
@class GPGController;

@protocol GPGControllerDelegate
@optional

- (void)gpgController:(GPGController *)gpgc operationDidFinishWithReturnValue:(id)value;
- (void)gpgController:(GPGController *)gpgc operationDidFailWithException:(NSException *)e;

@end



@interface GPGController : NSObject <GPGTaskDelegate> {
	NSMutableArray *signerKeys;
	NSMutableArray *comments;
	NSString *keyserver;
	NSUInteger keyserverTimeout;
	NSDictionary *userInfo;
	BOOL useArmor;
	BOOL useTextMode;
	BOOL printVersion;
	BOOL useDefaultComments;
	BOOL trustAllKeys;
	BOOL async;
	
	NSObject <GPGControllerDelegate> *delegate;
	
	NSMutableArray *signatures;
	
	
	//Private
	id asyncProxy; //AsyncProxy
	GPGSignature *lastSignature;
	GPGTask *gpgTask;
	BOOL asyncStarted;
	BOOL canceled;
}

@property (assign) NSObject <GPGControllerDelegate> *delegate;
@property (readonly) NSArray *signerKeys;
@property (readonly) NSArray *comments;
@property (readonly) NSArray *signatures;
@property (retain) NSString *keyserver;
@property NSUInteger keyserverTimeout;
@property (retain) NSDictionary *userInfo;
@property BOOL async;
@property BOOL useArmor;
@property BOOL useTextMode;
@property BOOL printVersion;
@property BOOL useDefaultComments;
@property BOOL trustAllKeys;

- (void)addComment:(NSString *)comment;
- (void)removeCommentAtIndex:(NSUInteger)index;
- (void)addSignerKey:(NSString *)signerKey;
- (void)removeSignerKeyAtIndex:(NSUInteger)index;



+ (void)colonListing:(NSString *)colonListing toArray:(NSArray **)array andFingerprints:(NSArray **)fingerprints;
+ (NSSet *)fingerprintsFromColonListing:(NSString *)colonListing;
- (NSInteger)indexOfUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key;
- (NSInteger)indexOfSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key;


- (NSSet *)allKeys;
- (NSSet *)keysForSearchPattern:(NSString *)searchPattern;
- (NSSet *)keysForSearchPatterns:(id <EnumerationList>)searchPatterns;
- (NSSet *)updateKeys:(id <EnumerationList>)keyList;
- (NSSet *)updateKeys:(id <EnumerationList>)keyList withSigs:(BOOL)withSigs;
- (NSSet *)updateKeys:(id <EnumerationList>)keyList searchFor:(id <EnumerationList>)serachList withSigs:(BOOL)withSigs;

- (void)cancel;

- (void)cleanKey:(id <KeyFingerprint>)key;
- (void)minimizeKey:(id <KeyFingerprint>)key;
- (void)addPhotoFromPath:(NSString *)path toKey:(id <KeyFingerprint>)key;
- (void)removeUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key;
- (void)revokeUserID:(NSString *)hashID fromKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description;
- (NSString *)importFromData:(NSData *)data fullImport:(BOOL)fullImport;
- (NSData *)exportKeys:(id <EnumerationList>)keys allowSecret:(BOOL)allowSec fullExport:(BOOL)fullExport;
- (NSData *)genRevokeCertificateForKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description;
- (void)signUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key signKey:(id <KeyFingerprint>)signKey type:(NSInteger)type local:(BOOL)local daysToExpire:(NSInteger)daysToExpire;
- (void)addSubkeyToKey:(id <KeyFingerprint>)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addUserIDToKey:(id <KeyFingerprint>)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment;
- (void)setExpirationDateForSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key daysToExpire:(NSInteger)daysToExpire;
- (void)changePassphraseForKey:(id <KeyFingerprint>)key;
- (NSString *)receiveKeysFromServer:(id <EnumerationList>)keys;
- (void)removeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(id <KeyFingerprint>)key;
- (void)removeSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key;
- (void)revokeSubkey:(id <KeyFingerprint>)subkey fromKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description;
- (void)setPrimaryUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key;
- (void)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(NSInteger)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(NSInteger)subkeyLength 
				  daysToExpire:(NSInteger)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase;
- (void)deleteKeys:(id <EnumerationList>)keys withMode:(GPGDeleteKeyMode)mode;
- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(id <KeyFingerprint>)key;
- (NSArray *)searchKeysOnServer:(NSString *)pattern;
- (void)revokeSignature:(GPGKeySignature *)signature fromUserID:(GPGUserID *)userID ofKey:(id <KeyFingerprint>)key reason:(int)reason description:(NSString *)description;
- (void)key:(id <KeyFingerprint>)key setDisabled:(BOOL)disabled;
- (void)key:(id <KeyFingerprint>)key setOwnerTrsut:(GPGValidity)trust;

- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(id <EnumerationList>)recipients hiddenRecipients:(id <EnumerationList>)hiddenRecipients;
- (NSData *)decryptData:(NSData *)data;
- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData;



@end


