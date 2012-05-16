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


@interface GPGSignature : NSObject {
	GPGValidity trust;
	GPGErrorCode status;
	
	NSString *fingerprint;
	NSString *primaryFingerprint;
	NSString *userID;
	NSString *name;
	NSString *email;
	NSString *comment;
	
	NSDate *creationDate;
	NSDate *expirationDate;
	
	int version;
	int publicKeyAlgorithm;
	int hashAlgorithm;
	NSString *signatureClass;
	
	BOOL hasFilled;
}
@property (readonly) GPGErrorCode status;
@property (readonly) GPGValidity trust;
@property (readonly) BOOL hasFilled;
@property (readonly) int version;
@property (readonly) int publicKeyAlgorithm;
@property (readonly) int hashAlgorithm;
@property (retain, readonly) NSString *fingerprint;
@property (retain, readonly) NSString *primaryFingerprint;
@property (retain, readonly) NSString *userID;
@property (retain, readonly) NSString *name;
@property (retain, readonly) NSString *email;
@property (retain, readonly) NSString *comment;
@property (retain, readonly) NSDate *creationDate;
@property (retain, readonly) NSDate *expirationDate;
@property (retain, readonly) NSString *signatureClass;


- (void)addInfoFromStatusCode:(NSInteger)status andPrompt:(NSString *)prompt;
// localized
- (NSString *)humanReadableDescription;
// really for unit-testing
- (NSString *)humanReadableDescriptionShouldLocalize:(BOOL)shouldLocalize;

@end
