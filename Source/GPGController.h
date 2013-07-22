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

#import <Cocoa/Cocoa.h>
#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGKey.h>
#import <Libmacgpg/GPGTask.h>
#import <Libmacgpg/GPGKeyserver.h>

@class GPGSignature;
@class GPGUserIDSignature;
@class GPGController;
@class GPGStream;

@protocol GPGControllerDelegate
@optional

- (void)gpgController:(GPGController *)gpgc operationDidFinishWithReturnValue:(id)value;
- (void)gpgController:(GPGController *)gpgc operationThrownException:(NSException *)e;
- (void)gpgController:(GPGController *)gpgc keysDidChanged:(NSObject <EnumerationList> *)keys external:(BOOL)external;
- (void)gpgControllerOperationDidStart:(GPGController *)gpgc;
- (void)gpgController:(GPGController *)gpgc progressed:(NSInteger)progressed total:(NSInteger)total;


@end



@interface GPGController : NSObject <GPGTaskDelegate> {
	NSMutableArray *signerKeys;
	NSMutableArray *comments;
	NSMutableArray *signatures;
	NSString *filename; //May contain the filename after decryption.
	NSString *forceFilename; //May contain the filename after decryption.
	NSString *keyserver;
	NSUInteger keyserverTimeout;
	NSString *proxyServer;
	NSString *gpgHome;
	NSDictionary *userInfo;
	NSUndoManager *undoManager;
	BOOL useArmor;
	BOOL useTextMode;
	BOOL printVersion;
	BOOL useDefaultComments;
	BOOL trustAllKeys;
	BOOL async;
    BOOL verbose;
	BOOL autoKeyRetrieve;
    id lastReturnValue;
    
    GPGHashAlgorithm hashAlgorithm;
    
	
	NSObject <GPGControllerDelegate> *delegate;
	NSException *error;

	
	//Private
	NSString *identifier;
	id asyncProxy; //AsyncProxy
	GPGSignature *lastSignature;
	GPGTask *gpgTask;
	BOOL asyncStarted;
	BOOL canceled;
	NSInteger runningOperations;
	NSUInteger groupedKeyChange;
	NSUInteger timeout;
	
	NSMutableSet *gpgKeyservers;
	
	BOOL sandboxed;
}

@property (nonatomic, assign) NSObject <GPGControllerDelegate> *delegate;
@property (nonatomic, readonly) NSArray *signerKeys;
@property (nonatomic, readonly) NSArray *comments;
@property (nonatomic, readonly) NSArray *signatures;
@property (nonatomic, readonly) id lastReturnValue;
@property (nonatomic, readonly) NSException *error;
@property (nonatomic, readonly, retain) NSString *filename;
@property (nonatomic, retain) NSString *forceFilename;
@property (nonatomic, retain) NSString *keyserver;
@property (nonatomic, retain) NSString *proxyServer;
@property (nonatomic, retain) NSString *gpgHome;
@property (nonatomic) NSUInteger keyserverTimeout;
@property (nonatomic, retain) NSDictionary *userInfo;
@property (nonatomic, retain) NSUndoManager *undoManager;
@property (nonatomic, readonly) BOOL decryptionOkay;
@property (nonatomic) BOOL async;
@property (nonatomic) BOOL useArmor;
@property (nonatomic) BOOL useTextMode;
@property (nonatomic) BOOL printVersion;
@property (nonatomic) BOOL useDefaultComments;
@property (nonatomic) BOOL trustAllKeys;
@property (nonatomic) BOOL verbose DEPRECATED_ATTRIBUTE;
@property (nonatomic) BOOL autoKeyRetrieve;
@property (nonatomic, readonly) NSDictionary *statusDict;
@property (nonatomic, readonly) GPGHashAlgorithm hashAlgorithm;
@property (nonatomic, readonly) GPGTask *gpgTask;
@property (nonatomic, assign) NSUInteger timeout;
@property (nonatomic, assign) BOOL sandboxed;

+ (NSString *)gpgVersion;
+ (NSSet *)publicKeyAlgorithm;
+ (NSSet *)cipherAlgorithm;
+ (NSSet *)digestAlgorithm;
+ (NSSet *)compressAlgorithm;
+ (GPGErrorCode)testGPG;

+ (NSString *)nameForHashAlgorithm:(GPGHashAlgorithm)hashAlgorithm;

- (void)setComment:(NSString *)comment;
- (void)addComment:(NSString *)comment;
- (void)removeCommentAtIndex:(NSUInteger)index;
- (void)setSignerKey:(NSObject <KeyFingerprint> *)signerKey;
- (void)addSignerKey:(NSObject <KeyFingerprint> *)signerKey;
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
- (NSData *)exportKeys:(NSObject <EnumerationList> *)keys options:(GPGExportOptions)options;
- (NSData *)generateRevokeCertificateForKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)revokeKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)signUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key signKey:(NSObject <KeyFingerprint> *)signKey type:(int)type local:(BOOL)local daysToExpire:(int)daysToExpire;
- (void)addSubkeyToKey:(NSObject <KeyFingerprint> *)key type:(NSInteger)type length:(NSInteger)length daysToExpire:(NSInteger)daysToExpire;
- (void)addUserIDToKey:(NSObject <KeyFingerprint> *)key name:(NSString *)name email:(NSString *)email comment:(NSString *)comment;
- (void)setExpirationDateForSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key daysToExpire:(NSInteger)daysToExpire;
- (void)changePassphraseForKey:(NSObject <KeyFingerprint> *)key;
- (NSString *)receiveKeysFromServer:(NSObject <EnumerationList> *)keys;
- (NSArray *)searchKeysOnServer:(NSString *)pattern;
- (void)sendKeysToServer:(NSObject <EnumerationList> *)keys;
- (NSString *)refreshKeysFromServer:(NSObject <EnumerationList> *)keys DEPRECATED_ATTRIBUTE;
- (void)removeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)removeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeSubkey:(NSObject <KeyFingerprint> *)subkey fromKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)setPrimaryUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (NSString *)generateNewKeyWithName:(NSString *)name email:(NSString *)email comment:(NSString *)comment 
					   keyType:(GPGPublicKeyAlgorithm)keyType keyLength:(int)keyLength subkeyType:(GPGPublicKeyAlgorithm)subkeyType subkeyLength:(int)subkeyLength 
				  daysToExpire:(int)daysToExpire preferences:(NSString *)preferences passphrase:(NSString *)passphrase;
- (void)deleteKeys:(NSObject <EnumerationList> *)keys withMode:(GPGDeleteKeyMode)mode;
- (void)setAlgorithmPreferences:(NSString *)preferences forUserID:(NSString *)hashID ofKey:(NSObject <KeyFingerprint> *)key;
- (void)revokeSignature:(GPGUserIDSignature *)signature fromUserID:(GPGUserID *)userID ofKey:(NSObject <KeyFingerprint> *)key reason:(int)reason description:(NSString *)description;
- (void)key:(NSObject <KeyFingerprint> *)key setDisabled:(BOOL)disabled;
- (void)key:(NSObject <KeyFingerprint> *)key setOwnerTrsut:(GPGValidity)trust;

- (void)processTo:(GPGStream *)output data:(GPGStream *)input withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients;
- (NSData *)processData:(NSData *)data withEncryptSignMode:(GPGEncryptSignMode)encryptSignMode 
			 recipients:(NSObject <EnumerationList> *)recipients hiddenRecipients:(NSObject <EnumerationList> *)hiddenRecipients;

- (void)decryptTo:(GPGStream *)output data:(GPGStream *)input;
- (NSData *)decryptData:(NSData *)data;

- (NSArray *)verifySignatureOf:(GPGStream *)signatureInput originalData:(GPGStream *)originalInput;
- (NSArray *)verifySignature:(NSData *)signatureData originalData:(NSData *)originalData;

- (NSArray *)verifySignedData:(NSData *)signedData;
- (NSSet *)keysInExportedData:(NSData *)data;



@end


