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

#import <Cocoa/Cocoa.h>

@interface GPGConfLine : NSObject {
	NSString *name;
	NSString *value;
	NSMutableArray *subOptions;
	BOOL enabled;
	BOOL isComment;
	BOOL edited;
	NSString *description;
	NSUInteger hash;
}

@property (retain) NSString *name;
@property (retain) NSString *value;
@property (retain) NSArray *subOptions;
@property (readonly) NSUInteger subOptionsCount;
@property BOOL enabled;
@property BOOL isComment;


- (id)initWithLine:(NSString *)line;
+ (id)confLineWithLine:(NSString *)line;
+ (id)confLine;

@end
