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

#import <Cocoa/Cocoa.h>


enum {
	NoDefaultAnswer = 0,
	YesToAll,
	NoToAll
};
typedef uint8_t BoolAnswer;

@interface GPGTaskOrder : NSObject {
	uint8_t defaultBoolAnswer;
	
	NSMutableArray *items;
	NSUInteger index;
}

@property uint8_t defaultBoolAnswer;


- (void)addCmd:(NSString *)cmd prompt:(NSString *)prompt;
- (void)addInt:(int)cmd prompt:(NSString *)prompt;
- (void)addOptionalCmd:(NSString *)cmd prompt:(NSString *)prompt;
- (void)addOptionalInt:(int)cmd prompt:(NSString *)prompt;
- (void)addCmd:(NSString *)cmd prompt:(NSString *)prompt optional:(BOOL)optional;
- (void)addInt:(int)cmd prompt:(NSString *)prompt optional:(BOOL)optional;
- (NSString *)cmdForPrompt:(NSString *)prompt statusCode:(NSInteger)statusCode;

+ (id)order;
+ (id)orderWithYesToAll;
+ (id)orderWithNoToAll;
- (id)initWithYesToAll;
- (id)initWithNoToAll;

@end
