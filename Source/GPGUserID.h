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
#import <Libmacgpg/GPGSuper_Template.h>

@class GPGKey;

@interface GPGUserID : GPGSuper_Template <GPGUserIDProtocol> {
	NSInteger index;
	GPGKey *primaryKey;
	
	NSArray *signatures;
	
	NSArray *cipherPreferences;
	NSArray *digestPreferences;
	NSArray *compressPreferences;
	NSArray *otherPreferences;
	
	
	NSString *hashID;
	
	NSString *userID;
	NSString *name;
	NSString *email;
	NSString *comment;
}

@property (nonatomic) NSInteger index;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSArray *signatures;

@property (nonatomic, readonly, assign) GPGKey *primaryKey;

@property (nonatomic, readonly, retain) NSArray *cipherPreferences;
@property (nonatomic, readonly, retain) NSArray *digestPreferences;
@property (nonatomic, readonly, retain) NSArray *compressPreferences;
@property (nonatomic, readonly, retain) NSArray *otherPreferences;

@property (nonatomic, readonly, retain) NSString *hashID;

@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *comment;


//Dummys
@property (nonatomic, readonly) id children;
@property (nonatomic, readonly) id keyID;
@property (nonatomic, readonly) id shortKeyID;
@property (nonatomic, readonly) id fingerprint;
@property (nonatomic, readonly) id length;
@property (nonatomic, readonly) id algorithm;
@property (nonatomic, readonly) id capabilities;


- (id)initWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing parentKey:(GPGKey *)key;
- (void)updateWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing;
- (void)updatePreferences:(NSString *)listing;

@end
