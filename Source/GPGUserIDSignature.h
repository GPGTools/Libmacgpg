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
#import <Libmacgpg/GPGUserID.h>

@class GPGKey;


@interface GPGUserIDSignature : NSObject <GPGUserIDProtocol> {
	NSString *_keyID;
	GPGPublicKeyAlgorithm _algorithm;
	NSDate *_creationDate;
	NSDate *_expirationDate;
	NSString *_reason;
	int _signatureClass;
	BOOL _revocation;
	BOOL _local;

	GPGKey *__unsafe_unretained _primaryKey;
}

- (instancetype)init;
- (instancetype)initWithKeyID:(NSString *)keyID;

@property (copy, nonatomic, readonly) NSString *keyID;
@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (copy, nonatomic, readonly) NSDate *creationDate;
@property (copy, nonatomic, readonly) NSDate *expirationDate;
@property (copy, nonatomic, readonly) NSString *reason;
@property (nonatomic, readonly) int signatureClass;
@property (nonatomic, readonly) BOOL revocation;
@property (nonatomic, readonly) BOOL local;

@property (unsafe_unretained, nonatomic, readonly) GPGKey *primaryKey;

@property (copy, nonatomic, readonly) NSString *userIDDescription;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *email;
@property (copy, nonatomic, readonly) NSString *comment;
@property (copy, nonatomic, readonly) NSImage *image;

@end
