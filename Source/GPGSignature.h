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


@interface GPGSignature : NSObject <GPGUserIDProtocol> {
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
@property (nonatomic, readonly) GPGErrorCode status;
@property (nonatomic, readonly) GPGValidity trust;
@property (nonatomic, readonly) BOOL hasFilled;
@property (nonatomic, readonly) int version;
@property (nonatomic, readonly) int publicKeyAlgorithm;
@property (nonatomic, readonly) int hashAlgorithm;
@property (nonatomic, retain, readonly) NSString *fingerprint;
@property (nonatomic, retain, readonly) NSString *primaryFingerprint;
@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain, readonly) NSDate *creationDate;
@property (nonatomic, retain, readonly) NSDate *expirationDate;
@property (nonatomic, retain, readonly) NSString *signatureClass;


- (void)addInfoFromStatusCode:(NSInteger)status andPrompt:(NSString *)prompt;
// localized
- (NSString *)humanReadableDescription;
// really for unit-testing
- (NSString *)humanReadableDescriptionShouldLocalize:(BOOL)shouldLocalize;

@end
