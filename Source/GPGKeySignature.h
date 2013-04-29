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

@property (nonatomic, readonly) BOOL local;
@property (nonatomic, readonly) BOOL revocationSignature;
@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, readonly) int signatureClass;
@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, retain) NSString *userID;
@property (nonatomic, readonly, retain) NSString *name;
@property (nonatomic, readonly, retain) NSString *email;
@property (nonatomic, readonly, retain) NSString *comment;
@property (nonatomic, readonly, retain) NSString *keyID;
@property (nonatomic, readonly, retain) NSString *shortKeyID;
@property (nonatomic, readonly, retain) NSString *description;
@property (nonatomic, readonly, retain) NSDate *creationDate;
@property (nonatomic, readonly, retain) NSDate *expirationDate;


+ (NSArray *)signaturesWithListing:(NSArray *)listing;
+ (id)signatureWithListing:(NSArray *)listing;
- (id)initWithListing:(NSArray *)listing;

@end
