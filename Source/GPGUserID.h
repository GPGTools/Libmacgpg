/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGSuper_Template.h>

@class GPGKey;

@interface GPGUserID : GPGSuper_Template {
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

@property NSInteger index;
@property (assign) GPGKey *primaryKey;
@property (readonly) NSString *type;

@property (readonly) NSArray *signatures;

@property (readonly) NSArray *cipherPreferences;
@property (readonly) NSArray *digestPreferences;
@property (readonly) NSArray *compressPreferences;
@property (readonly) NSArray *otherPreferences;

@property (retain) NSString *hashID;

@property (retain) NSString *userID;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;

@property (readonly) id children;
@property (readonly) id keyID;
@property (readonly) id shortKeyID;
@property (readonly) id fingerprint;
@property (readonly) id length;
@property (readonly) id algorithm;


- (id)initWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing parentKey:(GPGKey *)key;
- (void)updateWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing;
- (void)updatePreferences:(NSString *)listing;

@end
