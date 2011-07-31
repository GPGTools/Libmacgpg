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

#import <Libmacgpg/GPGGlobals.h>

@interface GPGKeySignature : NSObject {
	NSString *keyID;
	NSString *shortKeyID;
	
	NSString *type;
	
	int signatureClass;
	
	GPGPublicKeyAlgorithm algorithm;
	NSDate *creationDate;
	NSDate *expirationDate;
	
	
	NSString *description;
	
	NSString *userID;
	NSString *name;
	NSString *email;
	NSString *comment;
	
	BOOL revocationSignature;
	BOOL local;
}

@property (readonly) BOOL local;
@property (readonly) BOOL revocationSignature;
@property (readonly) GPGPublicKeyAlgorithm algorithm;
@property (readonly) int signatureClass;
@property (readonly, copy) NSString *type;
@property (readonly, retain) NSString *userID;
@property (readonly, retain) NSString *name;
@property (readonly, retain) NSString *email;
@property (readonly, retain) NSString *comment;
@property (readonly, retain) NSString *keyID;
@property (readonly, retain) NSString *shortKeyID;
@property (readonly, retain) NSString *description;
@property (readonly, retain) NSDate *creationDate;
@property (readonly, retain) NSDate *expirationDate;


+ (NSArray *)signaturesWithListing:(NSArray *)listing;
+ (id)signatureWithListing:(NSArray *)listing;
- (id)initWithListing:(NSArray *)listing;

@end
