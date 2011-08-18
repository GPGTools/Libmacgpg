/*
 Copyright © Lukas Pitschl, 2011
 
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

#import <Foundation/Foundation.h>

typedef void (^lpxt_task_t)(void);

@interface LPXTTask : NSObject {
    id _standardInput;
    id _standardOutput;
    id _standardError;
    
    NSArray *_arguments;
    NSDictionary *_environment;
    NSString *_launchPath;
    NSString *_currentDirectoryPath;
    
    int _processIdentifier;
    int _terminationStatus;
    
    lpxt_task_t _parentTask;
	
	BOOL _cancelled;

@private
    CFMutableArrayRef _inheritedPipes;
    NSMutableDictionary *_inheritedPipesMap;
	
}

- (void)launchAndWait;
- (void)inheritPipe:(NSPipe *)pipe mode:(int)mode dup:(int)dupfd name:(NSString *)name;
- (void)inheritPipes:(NSArray *)pipes mode:(int)mode dups:(NSArray *)dupfds name:(NSString *)name;
- (NSPipe *)inheritedPipeWithName:(NSString *)name;
- (NSArray *)inheritedPipesWithName:(NSString *)name;
- (void)removeInheritedPipeWithName:(NSString *)name;

@property (retain) id standardInput;
@property (retain) id standardOutput;
@property (retain) id standardError;
@property (retain) NSArray *arguments;
@property (retain) NSDictionary *environment;
@property (copy) NSString *launchPath;
@property (copy) NSString *currentDirectoryPath;
@property (readonly) int processIdentifier;
@property (readonly) int terminationStatus;
@property (retain) lpxt_task_t parentTask;
@property (readonly) BOOL cancelled;

- (void)cancel;
//- (void)terminate;
//- (void)suspend;
//- (void)resume;

@end
