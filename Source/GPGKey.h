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
	NSMutableArray *children;
	NSMutableArray *subkeys;
	NSMutableArray *userIDs;
	NSMutableArray *photos;
	
	NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
	NSString *allFingerprints;
	
	GPGUserID *primaryUserID;
	NSString *fingerprint;
	GPGValidity ownerTrust;
	BOOL secret;
}

@property (readonly, retain) NSMutableArray *photos;
@property (readonly, retain) NSString *textForFilter; //In diesem String stehen die verschiedenen Informationen über den Schlüssel, damit das Filtern schnell funktioniert.
@property (readonly, retain) NSString *allFingerprints;
@property (readonly, retain) NSString *fingerprint;
@property (readonly) GPGValidity ownerTrust;
@property (readonly) BOOL secret;
//@property (readonly) BOOL safe; //Gibt an ob der Schlüssel sicher ist. (Länge > 1024 Bit, kein MD5 oder SHA-1)
@property (readonly) GPGUserID *primaryUserID;
@property (readonly) GPGKey *primaryKey;
@property (readonly) NSString *type;
@property (readonly) NSInteger index;
@property (readonly) NSString *userID;
@property (readonly) NSString *name;
@property (readonly) NSString *email;
@property (readonly) NSString *comment;

- (void)setChildren:(NSMutableArray *)value;
- (NSArray *)children;
- (unsigned)countOfChildren;
- (id)objectInChildrenAtIndex:(unsigned)theIndex;
- (void)getChildren:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inChildrenAtIndex:(unsigned)theIndex;
- (void)removeObjectFromChildrenAtIndex:(unsigned)theIndex;
- (void)replaceObjectInChildrenAtIndex:(unsigned)theIndex withObject:(id)obj;
- (void)removeObjectsFromChildrenIdenticalTo:(id <NSFastEnumeration>)objects;

- (void)setSubkeys:(NSMutableArray *)value;
- (NSArray *)subkeys;
- (unsigned)countOfSubkeys;
- (id)objectInSubkeysAtIndex:(unsigned)theIndex;
- (void)getSubkeys:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inSubkeysAtIndex:(unsigned)theIndex;
- (void)removeObjectFromSubkeysAtIndex:(unsigned)theIndex;
- (void)replaceObjectInSubkeysAtIndex:(unsigned)theIndex withObject:(id)obj;
- (void)removeObjectsFromSubkeysIdenticalTo:(id <NSFastEnumeration>)objects;

- (void)setUserIDs:(NSMutableArray *)value;
- (NSArray *)userIDs;
- (unsigned)countOfUserIDs;
- (id)objectInUserIDsAtIndex:(unsigned)theIndex;
- (void)getUserIDs:(id *)objsPtr range:(NSRange)range;
- (void)insertObject:(id)obj inUserIDsAtIndex:(unsigned)theIndex;
- (void)removeObjectFromUserIDsAtIndex:(unsigned)theIndex;
- (void)replaceObjectInUserIDsAtIndex:(unsigned)theIndex withObject:(id)obj;
- (void)removeObjectsFromUserIDsIdenticalTo:(id <NSFastEnumeration>)objects;



+ (void)setInfosWithUserID:(NSString *)aUserID toObject:(NSObject <GPGUserIDProtocol> *)object;

+ (id)keyWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;
- (void)updateWithListing:(NSArray *)listing isSecret:(BOOL)isSec withSigs:(BOOL)withSigs;

- (void)updatePreferences;


@end
