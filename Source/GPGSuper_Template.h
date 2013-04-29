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


@interface GPGSuper_Template : NSObject {
	GPGValidity validity;
	BOOL expired;
	BOOL disabled;
	BOOL invalid;
	BOOL revoked;	
	
	NSDate *creationDate;
	NSDate *expirationDate;
}
@property (nonatomic, readonly) GPGValidity validity;
@property (nonatomic, readonly) BOOL expired, disabled, invalid, revoked;
@property (nonatomic, readonly) NSInteger status;
@property (nonatomic, readonly, retain) NSDate *creationDate, *expirationDate;


+ (GPGValidity)validityFromLetter:(NSString *)letter;
- (void)updateWithLine:(NSArray *)line;

@end
