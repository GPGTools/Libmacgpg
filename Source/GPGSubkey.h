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
#import <Libmacgpg/GPGKey_Template.h>

@class GPGKey;

@interface GPGSubkey : GPGKey_Template <KeyFingerprint> {
	NSInteger index;
	GPGKey *primaryKey;
	
	NSString *fingerprint;
}

@property (nonatomic) NSInteger index;
@property (nonatomic, readonly, assign) GPGKey *primaryKey;
@property (nonatomic, readonly, retain) NSString *fingerprint;
@property (nonatomic, readonly) NSString *type;

//Dummys
@property (nonatomic, readonly) id children;
@property (nonatomic, readonly) id name;
@property (nonatomic, readonly) id email;
@property (nonatomic, readonly) id comment;



- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint parentKey:(GPGKey *)key;
- (void)updateWithListing:(NSArray *)listing;

@end
