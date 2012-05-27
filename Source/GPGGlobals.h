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

#import <Cocoa/Cocoa.h>
#import <Libmacgpg/GPGException.h>
#import <Libmacgpg/GPGOptions.h>

@class GPGTask;

typedef enum { 
    GPGKeyStatus_Invalid = 8,
    GPGKeyStatus_Revoked = 16,
    GPGKeyStatus_Expired = 32,
    GPGKeyStatus_Disabled = 64
} GPGKeyStatus;
typedef enum {
    GPGValidityUnknown   = 0,
    GPGValidityUndefined = 1,
    GPGValidityNever     = 2,
    GPGValidityMarginal  = 3,
    GPGValidityFull      = 4,
    GPGValidityUltimate  = 5
} GPGValidity;
typedef enum {
    GPG_RSAAlgorithm                =  1,
    GPG_RSAEncryptOnlyAlgorithm     =  2,
    GPG_RSASignOnlyAlgorithm        =  3,
    GPG_ElgamalEncryptOnlyAlgorithm = 16,
    GPG_DSAAlgorithm                = 17,
    GPG_EllipticCurveAlgorithm      = 18,
    GPG_ECDSAAlgorithm              = 19,
    GPG_ElgamalAlgorithm            = 20,
    GPG_DiffieHellmanAlgorithm      = 21
} GPGPublicKeyAlgorithm;
typedef enum {
    GPGPublicKeyEncrypt = 1,
	GPGSymetricEncrypt = 2,
	
	
	//You can choose only one sign Mode.
    GPGSign = 8,
    GPGSeparateSign = 16,
	GPGClearSign = GPGSign | 32,
	GPGDetachedSign = GPGSign | 64,
	
	GPGEncryptSign = GPGPublicKeyEncrypt | GPGSign,
	GPGEncryptSeparateSign = GPGPublicKeyEncrypt | GPGSeparateSign,
	GPGEncryptSeparateClearSign = GPGPublicKeyEncrypt | GPGSeparateSign | GPGClearSign,
	
	GPGEncryptFlags = 3,
	GPGSignFlags = 120
} GPGEncryptSignMode;

typedef enum {
	GPGDeletePublicKey,
	GPGDeleteSecretKey,
	GPGDeletePublicAndSecretKey
} GPGDeleteKeyMode;

typedef enum {
	GPGPublicKeyEncryptedSessionKeyPacket = 1,
	GPGSignaturePacket = 2,
	GPGSymmetricEncryptedSessionKeyPacket = 3,
	GPGOnePassSignaturePacket = 4,
	GPGSecretKeyPacket = 5,
	GPGPublicKeyPacket = 6,
	GPGSecretSubkeyPacket = 7,
	GPGCompressedDataPacket = 8,
	GPGSymmetricEncryptedDataPacket = 9,
	GPGMarkerPacket = 10,
	GPGLiteralDataPacket = 11,
	GPGTrustPacket = 12,
	GPGUserIDPacket = 13,
	GPGPublicSubkeyPacket = 14,
	GPGUserAttributePacket = 17,
	GPGSymmetricEncryptedProtectedDataPacket = 18,
	GPGModificationDetectionCodePacket = 19
} GPGPacketType;

typedef enum {
	GPGContent_Message,
	GPGContent_SignedMessage,
	GPGContent_Signature,
	GPGContent_Key
} GPGContentType;

typedef enum {
    GPGHashAlgorithmMD5 = 1,
    GPGHashAlgorithmSHA1 = 2,
    GPGHashAlgorithmRMD160 = 3,
    GPGHashAlgorithmSHA256 = 8,
    GPGHashAlgorithmSHA384 = 9,
    GPGHashAlgorithmSHA512 = 10,
    GPGHashAlgorithmSHA224 = 11
} GPGHashAlgorithm;

enum gpgStatusCodes {
	GPG_STATUS_NONE = 0, //No Status Code!
	
	GPG_STATUS_ALREADY_SIGNED,
	GPG_STATUS_ATTRIBUTE,
	GPG_STATUS_BACKUP_KEY_CREATED,
	GPG_STATUS_BADARMOR,
	GPG_STATUS_BADSIG,
	GPG_STATUS_BAD_PASSPHRASE,
	GPG_STATUS_BEGIN_DECRYPTION,
	GPG_STATUS_BEGIN_ENCRYPTION,
	GPG_STATUS_BEGIN_SIGNING,
	GPG_STATUS_BEGIN_STREAM,
	GPG_STATUS_CARDCTRL,
	GPG_STATUS_DECRYPTION_FAILED,
	GPG_STATUS_DECRYPTION_OKAY,
	GPG_STATUS_DELETE_PROBLEM,
	GPG_STATUS_ENC_TO,
	GPG_STATUS_END_DECRYPTION,
	GPG_STATUS_END_ENCRYPTION,
	GPG_STATUS_END_STREAM,
	GPG_STATUS_ERROR,
	GPG_STATUS_ERRSIG,
	GPG_STATUS_EXPKEYSIG,
	GPG_STATUS_EXPSIG,
	GPG_STATUS_FILE_DONE,
	GPG_STATUS_GET_BOOL,
	GPG_STATUS_GET_HIDDEN,
	GPG_STATUS_GET_LINE,
	GPG_STATUS_GOODSIG,
	GPG_STATUS_GOOD_PASSPHRASE,
	GPG_STATUS_GOT_IT,
	GPG_STATUS_IMPORTED,
	GPG_STATUS_IMPORT_CHECK,
	GPG_STATUS_IMPORT_OK,
	GPG_STATUS_IMPORT_PROBLEM,
	GPG_STATUS_IMPORT_RES,
	GPG_STATUS_INV_RECP,
	GPG_STATUS_INV_SGNR,
	GPG_STATUS_KEYEXPIRED,
	GPG_STATUS_KEYREVOKED,
	GPG_STATUS_KEY_CREATED,
	GPG_STATUS_KEY_NOT_CREATED,
	GPG_STATUS_MISSING_PASSPHRASE,
	GPG_STATUS_NEED_PASSPHRASE,
	GPG_STATUS_NEED_PASSPHRASE_PIN,
	GPG_STATUS_NEED_PASSPHRASE_SYM,
	GPG_STATUS_NEWSIG,
	GPG_STATUS_NODATA,
	GPG_STATUS_NOTATION_DATA,
	GPG_STATUS_NOTATION_NAME,
	GPG_STATUS_NO_PUBKEY,
	GPG_STATUS_NO_RECP,
	GPG_STATUS_NO_SECKEY,
	GPG_STATUS_NO_SGNR,
	GPG_STATUS_PKA_TRUST_BAD,
	GPG_STATUS_PKA_TRUST_GOOD,
	GPG_STATUS_PLAINTEXT,
	GPG_STATUS_PLAINTEXT_LENGTH,
	GPG_STATUS_POLICY_URL,
	GPG_STATUS_PROGRESS,
	GPG_STATUS_REVKEYSIG,
	GPG_STATUS_RSA_OR_IDEA,
	GPG_STATUS_SC_OP_FAILURE,
	GPG_STATUS_SC_OP_SUCCESS,
	GPG_STATUS_SESSION_KEY,
	GPG_STATUS_SHM_GET,
	GPG_STATUS_SHM_GET_BOOL,
	GPG_STATUS_SHM_GET_HIDDEN,
	GPG_STATUS_SHM_INFO,
	GPG_STATUS_SIGEXPIRED,
	GPG_STATUS_SIG_CREATED,
	GPG_STATUS_SIG_ID,
	GPG_STATUS_SIG_SUBPACKET,
	GPG_STATUS_TRUNCATED,
	GPG_STATUS_TRUST_FULLY,
	GPG_STATUS_TRUST_MARGINAL,
	GPG_STATUS_TRUST_NEVER,
	GPG_STATUS_TRUST_ULTIMATE,
	GPG_STATUS_TRUST_UNDEFINED,
	GPG_STATUS_UNEXPECTED,
	GPG_STATUS_USERID_HINT,
	GPG_STATUS_VALIDSIG,
	GPG_STATUS_GOODMDC,
	GPG_STATUS_BADMDC,
	GPG_STATUS_ERRMDC,
	
	GPG_STATUS_COUNT //Count of Status Codes.
};




#define localizedLibmacgpgString(key) [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] localizedStringForKey:(key) value:@"" table:@""]
#define GPGDebugLog(...) {if ([GPGOptions debugLog]) NSLog(__VA_ARGS__);}
#define GPG_SERVICE_NAME "GnuPG"

extern NSString * const GPGKeysChangedNotification;
extern NSString * const GPGOptionsChangedNotification;
extern NSString * const GPGConfigurationModifiedNotification;





@interface NSData (GPGExtension)
- (NSString *)gpgString;
@end

@interface NSString (GPGExtension)
- (NSData *)UTF8Data;
- (NSUInteger)UTF8Length;
- (NSString *)shortKeyID;
- (NSString *)keyID;
- (NSString *)unescapedString;
@end

@interface NSDate (GPGExtension)
+ (id)dateWithGPGString:(NSString *)string;
@end


int hexToByte (const char *text);
NSString* bytesToHexString(const uint8_t *bytes, NSUInteger length);
NSSet *fingerprintsFromStatusText(NSString *statusText);
#if MAC_OS_X_VERSION_MIN_REQUIRED == MAC_OS_X_VERSION_10_6
void *memmem(const void *big, size_t big_len, const void *little, size_t little_len);
#endif



@protocol GPGUserIDProtocol
@property (retain) NSString *userID;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;
@end


@protocol EnumerationList <NSFastEnumeration>
- (NSUInteger)count;
@end
@protocol KeyFingerprint
- (NSString *)description;
@end

@interface NSArray (IndexInfo)
- (NSIndexSet *)indexesOfIdenticalObjects:(id <NSFastEnumeration>)objects;
@end
@interface NSArray (KeyList) <EnumerationList>
@end

@interface NSSet (GPGExtension)
- (NSSet *)usableGPGKeys;
@end
@interface NSSet (KeyList) <EnumerationList>
@end
@interface NSString (KeyFingerprint) <KeyFingerprint>
@end



@interface AsyncProxy : NSProxy {
	NSObject *realObject;
}
@property (assign) NSObject *realObject;
+ (id)proxyWithRealObject:(NSObject *)object;
- (id)initWithRealObject:(NSObject *)realObject;
- (id)init;
@end

// a little category to fcntl F_SETNOSIGPIPE on each fd
@interface NSPipe (SetNoSIGPIPE)
- (NSPipe *)noSIGPIPE;
@end

