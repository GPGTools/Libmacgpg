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
    GPGErrorNoError = 0, 
    GPGErrorGeneralError = 1, 
    GPGErrorUnknownPacket = 2, 
    GPGErrorUnknownVersion = 3, 
    GPGErrorInvalidPublicKeyAlgorithm = 4, 
    GPGErrorInvalidDigestAlgorithm = 5, 
    GPGErrorBadPublicKey = 6, 
    GPGErrorBadSecretKey = 7, 
    GPGErrorBadSignature = 8, 
    GPGErrorNoPublicKey = 9, 
    GPGErrorChecksumError = 10, 
    GPGErrorBadPassphrase = 11, 
    GPGErrorInvalidCipherAlgorithm = 12, 
    GPGErrorOpenKeyring = 13, 
    GPGErrorInvalidPacket = 14, 
    GPGErrorInvalidArmor = 15, 
    GPGErrorNoUserID = 16, 
    GPGErrorNoSecretKey = 17, 
    GPGErrorWrongSecretKey = 18, 
    GPGErrorBadSessionKey = 19, 
    GPGErrorUnknownCompressionAlgorithm = 20, 
    GPGErrorNoPrime = 21, 
    GPGErrorNoEncodingMethod = 22, 
    GPGErrorNoEncryptionScheme = 23, 
    GPGErrorNoSignatureScheme = 24, 
    GPGErrorInvalidAttribute = 25, 
    GPGErrorNoValue = 26, 
    GPGErrorNotFound = 27, 
    GPGErrorValueNotFound = 28, 
    GPGErrorSyntax = 29, 
    GPGErrorBadMPI = 30, 
    GPGErrorInvalidPassphrase = 31, 
    GPGErrorSignatureClass = 32, 
    GPGErrorResourceLimit = 33, 
    GPGErrorInvalidKeyring = 34, 
    GPGErrorTrustDBError = 35, 
    GPGErrorBadCertificate = 36, 
    GPGErrorInvalidUserID = 37, 
    GPGErrorUnexpected = 38, 
    GPGErrorTimeConflict = 39, 
    GPGErrorKeyServerError = 40, 
    GPGErrorWrongPublicKeyAlgorithm = 41, 
    GPGErrorTributeToDA = 42, 
    GPGErrorWeakKey = 43, 
    GPGErrorInvalidKeyLength = 44, 
    GPGErrorInvalidArgument = 45, 
    GPGErrorBadURI = 46, 
    GPGErrorInvalidURI = 47, 
    GPGErrorNetworkError = 48, 
    GPGErrorUnknownHost = 49, 
    GPGErrorSelfTestFailed = 50, 
    GPGErrorNotEncrypted = 51, 
    GPGErrorNotProcessed = 52, 
    GPGErrorUnusablePublicKey = 53, 
    GPGErrorUnusableSecretKey = 54, 
    GPGErrorInvalidValue = 55, 
    GPGErrorBadCertificateChain = 56, 
    GPGErrorMissingCertificate = 57, 
    GPGErrorNoData = 58, 
    GPGErrorBug = 59, 
    GPGErrorNotSupported = 60, 
    GPGErrorInvalidOperationCode = 61, 
    GPGErrorTimeout = 62, 
    GPGErrorInternalError = 63, 
    GPGErrorEOFInGCrypt = 64, 
    GPGErrorInvalidObject = 65, 
    GPGErrorObjectTooShort = 66, 
    GPGErrorObjectTooLarge = 67, 
    GPGErrorNoObject = 68, 
    GPGErrorNotImplemented = 69, 
    GPGErrorConflict = 70, 
    GPGErrorInvalidCipherMode = 71, 
    GPGErrorInvalidFlag = 72, 
    GPGErrorInvalidHandle = 73, 
    GPGErrorTruncatedResult = 74, 
    GPGErrorIncompleteLine = 75, 
    GPGErrorInvalidResponse = 76, 
    GPGErrorNoAgent = 77, 
    GPGErrorAgentError = 78, 
    GPGErrorInvalidData = 79, 
    GPGErrorAssuanServerFault = 80, 
    GPGErrorAssuanError = 81, 
    GPGErrorInvalidSessionKey = 82, 
    GPGErrorInvalidSEXP = 83, 
    GPGErrorUnsupportedAlgorithm = 84, 
    GPGErrorNoPINEntry = 85, 
    GPGErrorPINEntryError = 86, 
    GPGErrorBadPIN = 87, 
    GPGErrorInvalidName = 88, 
    GPGErrorBadData = 89, 
    GPGErrorInvalidParameter = 90, 
    GPGErrorWrongCard = 91, 
    GPGErrorNoDirManager = 92, 
    GPGErrorDirManagerError = 93, 
    GPGErrorCertificateRevoked = 94, 
    GPGErrorNoCRLKnown = 95, 
    GPGErrorCRLTooOld = 96, 
    GPGErrorLineTooLong = 97, 
    GPGErrorNotTrusted = 98, 
    GPGErrorCancelled = 99, 
    GPGErrorBadCACertificate = 100, 
    GPGErrorCertificateExpired = 101, 
    GPGErrorCertificateTooYoung = 102, 
    GPGErrorUnsupportedCertificate = 103, 
    GPGErrorUnknownSEXP = 104, 
    GPGErrorUnsupportedProtection = 105, 
    GPGErrorCorruptedProtection = 106, 
    GPGErrorAmbiguousName = 107, 
    GPGErrorCardError = 108, 
    GPGErrorCardReset = 109, 
    GPGErrorCardRemoved = 110, 
    GPGErrorInvalidCard = 111, 
    GPGErrorCardNotPresent = 112, 
    GPGErrorNoPKCS15Application = 113, 
    GPGErrorNotConfirmed = 114, 
    GPGErrorConfigurationError = 115, 
    GPGErrorNoPolicyMatch = 116, 
    GPGErrorInvalidIndex = 117, 
    GPGErrorInvalidID = 118, 
    GPGErrorNoSCDaemon = 119, 
    GPGErrorSCDaemonError = 120, 
    GPGErrorUnsupportedProtocol = 121, 
    GPGErrorBadPINMethod = 122, 
    GPGErrorCardNotInitialized = 123, 
    GPGErrorUnsupportedOperation = 124, 
    GPGErrorWrongKeyUsage = 125, 
    GPGErrorNothingFound = 126, 
    GPGErrorWrongBLOBType = 127, 
    GPGErrorMissingValue = 128, 
    GPGErrorHardware = 129, 
    GPGErrorPINBlocked = 130, 
    GPGErrorUseConditions = 131, 
    GPGErrorPINNotSynced = 132, 
    GPGErrorInvalidCRL = 133, 
    GPGErrorBadBER = 134, 
    GPGErrorInvalidBER = 135, 
    GPGErrorElementNotFound = 136, 
    GPGErrorIdentifierNotFound = 137, 
    GPGErrorInvalidTag = 138, 
    GPGErrorInvalidLength = 139, 
    GPGErrorInvalidKeyInfo = 140, 
    GPGErrorUnexpectedTag = 141, 
    GPGErrorNotDEREncoded = 142, 
    GPGErrorNoCMSObject = 143, 
    GPGErrorInvalidCMSObject = 144, 
    GPGErrorUnknownCMSObject = 145, 
    GPGErrorUnsupportedCMSObject = 146, 
    GPGErrorUnsupportedEncoding = 147, 
    GPGErrorUnsupportedCMSVersion = 148, 
    GPGErrorUnknownAlgorithm = 149, 
    GPGErrorInvalidEngine = 150, 
    GPGErrorPublicKeyNotTrusted = 151, 
    GPGErrorDecryptionFailed = 152, 
    GPGErrorKeyExpired = 153, 
    GPGErrorSignatureExpired = 154, 
    GPGErrorEncodingProblem = 155, 
    GPGErrorInvalidState = 156, 
    GPGErrorDuplicateValue = 157, 
    GPGErrorMissingAction = 158, 
    GPGErrorModuleNotFound = 159, 
    GPGErrorInvalidOIDString = 160, 
    GPGErrorInvalidTime = 161, 
    GPGErrorInvalidCRLObject = 162, 
    GPGErrorUnsupportedCRLVersion = 163, 
    GPGErrorInvalidCertObject = 164, 
    GPGErrorUnknownName = 165, 
    GPGErrorLocaleProblem = 166, 
    GPGErrorNotLocked = 167, 
    GPGErrorProtocolViolation = 168, 
    GPGErrorInvalidMac = 169, 
    GPGErrorInvalidRequest = 170,  
    GPGErrorBufferTooShort = 200, 
    GPGErrorSEXPInvalidLengthSpec = 201, 
    GPGErrorSEXPStringTooLong = 202, 
    GPGErrorSEXPUnmatchedParenthese = 203, 
    GPGErrorSEXPNotCanonical = 204, 
    GPGErrorSEXPBadCharacter = 205, 
    GPGErrorSEXPBadQuotation = 206, 
    GPGErrorSEXPZeroPrefix = 207, 
    GPGErrorSEXPNestedDisplayHint = 208, 
    GPGErrorSEXPUnmatchedDisplayHint = 209, 
    GPGErrorSEXPUnexpectedPunctuation = 210, 
    GPGErrorSEXPBadHexCharacter = 211, 
    GPGErrorSEXPOddHexNumbers = 212, 
    GPGErrorSEXPBadOctalCharacter = 213,  
    GPGErrorTruncatedKeyListing = 1024, 
    GPGErrorUser2 = 1025, 
    GPGErrorUser3 = 1026, 
    GPGErrorUser4 = 1027, 
    GPGErrorUser5 = 1028, 
    GPGErrorUser6 = 1029, 
    GPGErrorUser7 = 1030, 
    GPGErrorUser8 = 1031, 
    GPGErrorUser9 = 1032, 
    GPGErrorUser10 = 1033, 
    GPGErrorUser11 = 1034, 
    GPGErrorUser12 = 1035, 
    GPGErrorUser13 = 1036, 
    GPGErrorUser14 = 1037, 
    GPGErrorUser15 = 1038, 
    GPGErrorUser16 = 1039,  
	GPGErrorTaskException, 
	GPGErrorSubkeyNotFound, 
    GPGErrorMissingErrno = 16381, 
    GPGErrorUnknownErrno = 16382, 
    GPGErrorEOF = 16383,  
    // The following error codes are used to map system errors.  
	GPGError_E2BIG = 16384, 
    GPGError_EACCES = 16385, 
    GPGError_EADDRINUSE = 16386, 
    GPGError_EADDRNOTAVAIL = 16387, 
    GPGError_EADV = 16388, 
    GPGError_EAFNOSUPPORT = 16389, 
    GPGError_EAGAIN = 16390, 
    GPGError_EALREADY = 16391, 
    GPGError_EAUTH = 16392, 
    GPGError_EBACKGROUND = 16393, 
    GPGError_EBADE = 16394, 
    GPGError_EBADF = 16395, 
    GPGError_EBADFD = 16396, 
    GPGError_EBADMSG = 16397, 
    GPGError_EBADR = 16398, 
    GPGError_EBADRPC = 16399, 
    GPGError_EBADRQC = 16400, 
    GPGError_EBADSLT = 16401, 
    GPGError_EBFONT = 16402, 
    GPGError_EBUSY = 16403, 
    GPGError_ECANCELLED = 16404, 
    GPGError_ECHILD = 16405, 
    GPGError_ECHRNG = 16406, 
    GPGError_ECOMM = 16407, 
    GPGError_ECONNABORTED = 16408, 
    GPGError_ECONNREFUSED = 16409, 
    GPGError_ECONNRESET = 16410, 
    GPGError_ED = 16411, 
    GPGError_EDEADLK = 16412, 
    GPGError_EDEADLOCK = 16413, 
    GPGError_EDESTADDRREQ = 16414, 
    GPGError_EDIED = 16415, 
    GPGError_EDOM = 16416, 
    GPGError_EDOTDOT = 16417, 
    GPGError_EDQUOT = 16418, 
    GPGError_EEXIST = 16419, 
    GPGError_EFAULT = 16420, 
    GPGError_EFBIG = 16421, 
    GPGError_EFTYPE = 16422, 
    GPGError_EGRATUITOUS = 16423, 
    GPGError_EGREGIOUS = 16424, 
    GPGError_EHOSTDOWN = 16425, 
    GPGError_EHOSTUNREACH = 16426, 
    GPGError_EIDRM = 16427, 
    GPGError_EIEIO = 16428, 
    GPGError_EILSEQ = 16429, 
    GPGError_EINPROGRESS = 16430, 
    GPGError_EINTR = 16431, 
    GPGError_EINVAL = 16432, 
    GPGError_EIO = 16433, 
    GPGError_EISCONN = 16434, 
    GPGError_EISDIR = 16435, 
    GPGError_EISNAM = 16436, 
    GPGError_EL2HLT = 16437, 
    GPGError_EL2NSYNC = 16438, 
    GPGError_EL3HLT = 16439, 
    GPGError_EL3RST = 16440, 
    GPGError_ELIBACC = 16441, 
    GPGError_ELIBBAD = 16442, 
    GPGError_ELIBEXEC = 16443, 
    GPGError_ELIBMAX = 16444, 
    GPGError_ELIBSCN = 16445, 
    GPGError_ELNRNG = 16446, 
    GPGError_ELOOP = 16447, 
    GPGError_EMEDIUMTYPE = 16448, 
    GPGError_EMFILE = 16449, 
    GPGError_EMLINK = 16450, 
    GPGError_EMSGSIZE = 16451, 
    GPGError_EMULTIHOP = 16452, 
    GPGError_ENAMETOOLONG = 16453, 
    GPGError_ENAVAIL = 16454, 
    GPGError_ENEEDAUTH = 16455, 
    GPGError_ENETDOWN = 16456, 
    GPGError_ENETRESET = 16457, 
    GPGError_ENETUNREACH = 16458, 
    GPGError_ENFILE = 16459, 
    GPGError_ENOANO = 16460, 
    GPGError_ENOBUFS = 16461, 
    GPGError_ENOCSI = 16462, 
    GPGError_ENODATA = 16463, 
    GPGError_ENODEV = 16464, 
    GPGError_ENOENT = 16465, 
    GPGError_ENOEXEC = 16466, 
    GPGError_ENOLCK = 16467, 
    GPGError_ENOLINK = 16468, 
    GPGError_ENOMEDIUM = 16469, 
    GPGError_ENOMEM = 16470, 
    GPGError_ENOMSG = 16471, 
    GPGError_ENONET = 16472, 
    GPGError_ENOPKG = 16473, 
    GPGError_ENOPROTOOPT = 16474, 
    GPGError_ENOSPC = 16475, 
    GPGError_ENOSR = 16476, 
    GPGError_ENOSTR = 16477, 
    GPGError_ENOSYS = 16478, 
    GPGError_ENOTBLK = 16479, 
    GPGError_ENOTCONN = 16480, 
    GPGError_ENOTDIR = 16481, 
    GPGError_ENOTEMPTY = 16482, 
    GPGError_ENOTNAM = 16483, 
    GPGError_ENOTSOCK = 16484, 
    GPGError_ENOTSUP = 16485, 
    GPGError_ENOTTY = 16486, 
    GPGError_ENOTUNIQ = 16487, 
    GPGError_ENXIO = 16488, 
    GPGError_EOPNOTSUPP = 16489, 
    GPGError_EOVERFLOW = 16490, 
    GPGError_EPERM = 16491, 
    GPGError_EPFNOSUPPORT = 16492, 
    GPGError_EPIPE = 16493, 
    GPGError_EPROCLIM = 16494, 
    GPGError_EPROCUNAVAIL = 16495, 
    GPGError_EPROGMISMATCH = 16496, 
    GPGError_EPROGUNAVAIL = 16497, 
    GPGError_EPROTO = 16498, 
    GPGError_EPROTONOSUPPORT = 16499, 
    GPGError_EPROTOTYPE = 16500, 
    GPGError_ERANGE = 16501, 
    GPGError_EREMCHG = 16502, 
    GPGError_EREMOTE = 16503, 
    GPGError_EREMOTEIO = 16504, 
    GPGError_ERESTART = 16505, 
    GPGError_EROFS = 16506, 
    GPGError_ERPCMISMATCH = 16507, 
    GPGError_ESHUTDOWN = 16508, 
    GPGError_ESOCKTNOSUPPORT = 16509, 
    GPGError_ESPIPE = 16510, 
    GPGError_ESRCH = 16511, 
    GPGError_ESRMNT = 16512, 
    GPGError_ESTALE = 16513, 
    GPGError_ESTRPIPE = 16514, 
    GPGError_ETIME = 16515, 
    GPGError_ETIMEDOUT = 16516, 
    GPGError_ETOOMANYREFS = 16517, 
    GPGError_ETXTBSY = 16518, 
    GPGError_EUCLEAN = 16519, 
    GPGError_EUNATCH = 16520, 
    GPGError_EUSERS = 16521, 
    GPGError_EWOULDBLOCK = 16522, 
    GPGError_EXDEV = 16523, 
    GPGError_EXFULL = 16524,  
    // This is one more than the largest allowed entry.  
    GPGError_CODE_DIM = 65536 
} GPGErrorCode;
typedef enum {
    GPGPublicKeyEncrypt = 1,
	GPGSymetricEncrypt = 2,
	
	
	//You can choose only one sign Mode.
    GPGSign = 8,
    GPGSeparateSign = 16,
	GPGClearSign = GPGSign | 32,
	GPGDetachedSign = GPGSign | 64,
	
	GPGEnryptSign = GPGPublicKeyEncrypt | GPGSign,
	GPGEnryptSeparateSign = GPGPublicKeyEncrypt | GPGSeparateSign,
	GPGEnryptSeparateClearSign = GPGPublicKeyEncrypt | GPGSeparateSign | GPGClearSign,
	
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
	GPG_STATUS_ERRMDC
};




#define localizedLibmacgpgString(key) [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] localizedStringForKey:(key) value:@"" table:@""]
#define GPG_SERVICE_NAME "GnuPG"

extern NSString *GPGTaskException;
extern NSString *GPGException;
extern NSString *GPGKeysChangedNotification;
extern NSString *GPGOptionsChangedNotification;





@interface NSData (GPGExtension)
- (NSString *)gpgString;
@end

@interface NSString (GPGExtension)
- (NSData *)gpgData;
- (NSUInteger)UTF8Length;
@end

@interface NSDate (GPGExtension)
+ (id)dateWithGPGString:(NSString *)string;
@end


int hexToByte (const char *text);
NSString* unescapeString(NSString *string);
NSString* getShortKeyID(NSString *keyID);
NSString* getKeyID(NSString *fingerprint);
NSString* bytesToHexString(const uint8_t *bytes, NSUInteger length);


NSException* gpgTaskException(NSString *name, NSString *reason, int errorCode, GPGTask *gpgTask);
NSException* gpgException(NSString *name, NSString *reason, int errorCode);
NSException* gpgExceptionWithUserInfo(NSString *name, NSString *reason, int errorCode, NSDictionary *userInfo);


@protocol GPGUserIDProtocol
@property (retain) NSString *userID;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;
/*- (NSString *)userID;
- (void)setUserID:(NSString *)value;
- (NSString *)name;
- (void)setName:(NSString *)value;
- (NSString *)email;
- (void)setEmail:(NSString *)value;
- (NSString *)comment;
- (void)setComment:(NSString *)value;*/
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


