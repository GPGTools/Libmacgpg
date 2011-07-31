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



@interface GPGConf : NSObject {
	NSString *path;
	NSStringEncoding encoding;
	NSMutableArray *confLines;
	BOOL autoSave;
}

@property (retain) NSString *path;
@property NSStringEncoding encoding;
@property BOOL autoSave;


+ (id)confWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;
- (void)loadConfig;
- (void)saveConfig;


- (NSArray *)optionsWithName:(NSString *)name;
- (NSArray *)enabledOptionsWithName:(NSString *)name;
- (NSArray *)disabledOptionsWithName:(NSString *)name;
- (NSArray *)optionsWithName:(NSString *)name state:(int)state;



- (void)addOptionWithName:(NSString *)name;
- (void)removeOptionWithName:(NSString *)name;
- (int)stateOfOptionWithName:(NSString *)name;
- (void)setValue:(NSString *)value forOptionWithName:(NSString *)name;
- (void)addOptionWithName:(NSString *)name andValue:(NSString *)value;
- (void)removeOptionWithName:(NSString *)name andValue:(NSString *)value;
- (void)setAllOptionsWithName:(NSString *)name values:(NSArray *)values;


@end
