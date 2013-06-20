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

#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGUserID.h>
#import <Libmacgpg/GPGSubkey.h>
#import <Libmacgpg/GPGKeySignature.h>
#import <Libmacgpg/GPGPhotoID.h>
#import <Libmacgpg/GPGKey_Template.h>




@interface GPGKey : GPGKey_Template <KeyFingerprint> {
	NSArray *children;
	NSArray *subkeys;
	NSArray *userIDs;
	NSArray *photos;
	
	NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
	NSString *allFingerprints;
	
	GPGUserID *primaryUserID;
	NSString *fingerprint;
	GPGValidity ownerTrust;
	BOOL secret;
	
	dispatch_once_t filterTextOnceToken;
}

@property (nonatomic, readonly, retain) NSArray *userIDs;
@property (nonatomic, readonly, retain) NSArray *subkeys;
@property (nonatomic, readonly, retain) NSArray *children;
@property (nonatomic, readonly, retain) NSArray *photos;
@property (nonatomic, readonly, retain) NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
@property (nonatomic, readonly, retain) NSString *allFingerprints;
@property (nonatomic, readonly, retain) NSString *fingerprint;
@property (nonatomic, readonly) GPGValidity ownerTrust;
@property (nonatomic, readonly) BOOL secret;
//@property (nonatomic, readonly) BOOL safe; //Gibt an ob der Schlüssel sicher ist. (Länge > 1024 Bit, kein MD5 oder SHA-1)
@property (nonatomic, readonly) GPGUserID *primaryUserID;
@property (nonatomic, readonly) GPGKey *primaryKey;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) NSString *userID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;




+ (void)setInfosWithUserID:(NSString *)aUserID toObject:(NSObject <GPGUserIDProtocol> *)object;

+ (id)keyWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (void)updateWithListing:(NSArray *)listing isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;

- (void)updatePreferences;


@end
