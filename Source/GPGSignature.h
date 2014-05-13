/*
 Copyright © Roman Zechmeister und Lukas Pitschl (@lukele), 2014
 
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

#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGException.h>
#import <Libmacgpg/GPGUserID.h>

@class GPGKey;


@interface GPGSignature : NSObject <GPGUserIDProtocol> {
	GPGValidity _trust;
	GPGErrorCode _status;
	
	NSString *_fingerprint;
	NSDate *_creationDate;
	NSDate *_expirationDate;
	int _signatureClass;
	int _version;
	GPGPublicKeyAlgorithm _publicKeyAlgorithm;
	GPGHashAlgorithm _hashAlgorithm;
	
	GPGKey *_key;
}

- (instancetype)init;
- (instancetype)initWithFingerprint:(NSString *)fingerprint status:(GPGErrorCode)status;
- (NSString *)humanReadableDescription;
// really for unit-testing
- (NSString *)humanReadableDescriptionShouldLocalize:(BOOL)shouldLocalize;

@property (nonatomic, readonly) GPGValidity trust;
@property (nonatomic, readonly) GPGErrorCode status;
@property (nonatomic, readonly) NSString *fingerprint;
@property (copy, nonatomic, readonly) NSDate *creationDate;
@property (copy, nonatomic, readonly) NSDate *expirationDate;
@property (nonatomic, readonly) int version;
@property (nonatomic, readonly) GPGPublicKeyAlgorithm publicKeyAlgorithm;
@property (nonatomic, readonly) GPGHashAlgorithm hashAlgorithm;
@property (nonatomic, readonly) int signatureClass;

@property (unsafe_unretained, nonatomic, readonly) GPGKey *primaryKey;
@property (atomic, strong, readwrite) GPGKey *key;
@property (unsafe_unretained, nonatomic, readonly) NSString *primaryFingerprint;

@property (copy, nonatomic, readonly) NSString *userIDDescription;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *email;
@property (copy, nonatomic, readonly) NSString *comment;
@property (copy, nonatomic, readonly) NSImage *image;

@end
