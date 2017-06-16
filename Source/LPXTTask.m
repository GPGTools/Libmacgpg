/*
 Copyright © Lukas Pitschl und Roman Zechmeister, 2017
 
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

#import "LPXTTask.h"
#import "GPGGlobals.h"
#import "NSPipe+NoSigPipe.h"
#import "crt_externs.h"
#import "GPGException.h"

typedef struct {
    int fd;
    int dupfd;
} lpxttask_fd;

@interface LPXTTask ()

- (void)inheritPipeWithMode:(int)mode dup:(int)dupfd name:(NSString *)name addIfExists:(BOOL)add;

@end


@implementation LPXTTask
@synthesize arguments, launchPath, terminationStatus, parentTask, environmentVariables=_environmentVariables, completed, processIdentifier;

- (id)init {
    self = [super init];
    if(self != nil) {
        inheritedPipes = [[NSMutableArray alloc] init];
        inheritedPipesMap = [[NSMutableDictionary alloc] init];
        pipeAccessQueue = dispatch_queue_create("org.gpgtools.Libmacgpg.xpc.pipeAccess", NULL); // NULL is SERIAL on 10.7+ and serial on 10.6
        hasCompletedQueue = dispatch_queue_create("org.gpgtools.Libmacgpg.xpc.taskHasCompleted", NULL);
    }
    return self;
}


- (void)launchAndWait {
    // This launch method is partly taken from BDSKTask.
	
	NSTask *task = [[NSTask new] autorelease];
	
	task.launchPath = launchPath;
	task.arguments = arguments;
	
	if (_environmentVariables) {
		NSMutableDictionary *environment = [[NSProcessInfo processInfo].environment.mutableCopy autorelease];
		[environment addEntriesFromDictionary:_environmentVariables];
		task.environment = environment;
	}
	
	[self inheritPipeWithMode:O_WRONLY dup:0 name:@"stdin"];
	[self inheritPipeWithMode:O_RDONLY dup:1 name:@"stdout"];
	[self inheritPipeWithMode:O_RDONLY dup:2 name:@"stderr"];
	
	
	NSPipe *inputPipe = [self inheritedPipeWithName:@"stdin"];
	NSPipe *outputPipe = [self inheritedPipeWithName:@"stdout"];
	NSPipe *errorPipe = [self inheritedPipeWithName:@"stderr"];
	
	
	task.standardInput = inputPipe.noSIGPIPE;
	task.standardOutput = outputPipe.noSIGPIPE;
	task.standardError = errorPipe.noSIGPIPE;
	
	[task launch];
	
	if (parentTask != nil) {
		parentTask();
	}

	
	[task waitUntilExit];
	terminationStatus = task.terminationStatus;
	
	self.completed = YES;
	
	// After running, clean up all the pipes, so no data can be written at this point.
	// Wouldn't make sense anyway, since the child has shutdown already.
	[self cleanupPipes];
}


/**
 All the magic happens in here.
 Each pipe add is not closed, when the children is initialized.
 Fd's not added are automatically closed.
 
 If there's already a pipe registered under the given name, one of 2 things happens:
 1.) addIfExists is set to true -> add the pipe under the given name.
 2.) addIfExists is set to NO -> don't add the pipe and raise an error!
 */
- (void)inheritPipeWithMode:(int)mode dup:(int)dupfd name:(NSString *)name addIfExists:(BOOL)addIfExists {
    // Create a dictionary holding additional information about the pipe.
    // This info is used later to close and dup the file descriptor which
    // is used by either parent or child.
    NSMutableDictionary *pipeInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:mode], @"mode",
                                     [NSNumber numberWithInt:dupfd], @"dupfd", nil];
    // Add the pipe to the inheritedPipes array.
    // A CFMutableArray is used instead of a NSMutableArray due to the fact,
    // that NSMutableArrays copy added values and CFMutableArrays only retain them.
    dispatch_sync(pipeAccessQueue, ^{
        [inheritedPipes addObject:[[NSPipe pipe] noSIGPIPE]];
        [pipeInfo setValue:[NSNumber numberWithInteger:inheritedPipes.count-1] forKey:@"pipeIdx"];
    });
    
    // The pipe info is add to the pipe maps.
    // If a pipe already exists under that name, it's added to the list of pipes the
    // name is referring to.
    __block NSMutableArray *pipeList = nil;
    dispatch_sync(pipeAccessQueue, ^{
        pipeList = (NSMutableArray *)[inheritedPipesMap valueForKey:name];
    });
    
    if([pipeList count] && !addIfExists) {
        @throw [NSException exceptionWithName:@"LPXTTask" 
                                       reason:[NSString stringWithFormat:@"A pipe is already registered under the name %@",
                                               name]
                                     userInfo:nil];
        return;
    }
    if(![pipeList count])
        pipeList = [NSMutableArray array];

    [pipeList addObject:pipeInfo];
    // Add the pipe list, if this is the first pipe to be added.
    dispatch_sync(pipeAccessQueue, ^{
        if([pipeList count] == 1)
            [inheritedPipesMap setValue:pipeList forKey:name];
    });
}

- (void)inheritPipeWithMode:(int)mode dup:(int)dupfd name:(NSString *)name {
    // Raise an error if the pipe already exists.
    [self inheritPipeWithMode:mode dup:dupfd name:name addIfExists:NO];
}

- (void)inheritPipesWithMode:(int)mode dups:(NSArray *)dupfds name:(NSString *)name {
    for(int i = 0; i < [dupfds count]; i++) {
        [self inheritPipeWithMode:mode dup:[[dupfds objectAtIndex:i] intValue] name:name addIfExists:YES];
    }
}

- (NSArray *)inheritedPipesWithName:(NSString *)name {
    // Find the pipe info matching the given name.
    __block NSMutableArray *pipeList = nil;
    dispatch_sync(pipeAccessQueue, ^{
        NSDictionary *pipeInfo = [inheritedPipesMap valueForKey:name];
        pipeList = [NSMutableArray array];
        for(id idx in [pipeInfo valueForKey:@"pipeIdx"]) {
            [pipeList addObject:[(NSArray *)inheritedPipes objectAtIndex:[idx intValue]]];
        }
    });
    return pipeList;
}

- (NSPipe *)inheritedPipeWithName:(NSString *)name {
    if(self.completed)
        return nil;
    NSArray *pipeList = [self inheritedPipesWithName:name];
    // If there's no pipe registered for that name, raise an error.
    if(![pipeList count] && pipeList != nil) {
        @throw [NSException exceptionWithName:@"NoPipeRegisteredUnderNameException" 
                                       reason:[NSString stringWithFormat:@"There's no pipe registered for name: %@", name] 
                                     userInfo:nil];
        
    }
    return [pipeList objectAtIndex:0];
}

- (void)removeInheritedPipeWithName:(NSString *)name {
    // Find the pipeInfo.
    dispatch_sync(pipeAccessQueue, ^{
        NSArray *pipeList = [inheritedPipesMap objectForKey:name];
        for(NSDictionary *pipeInfo in pipeList) {
            NSNumber *idx = [pipeInfo objectForKey:@"pipeIdx"];
            [inheritedPipes removeObjectAtIndex:[idx intValue]];
        }
        [inheritedPipesMap removeObjectForKey:name];
    });
}

- (void)setCompleted:(BOOL)hasCompleted {
	if(hasCompletedQueue == NULL) {
		completed = YES;
		return;
	}
	__block LPXTTask *weakSelf = self;
	dispatch_async(hasCompletedQueue, ^{
        weakSelf->completed = YES;
    });
}

- (BOOL)completed {
    BOOL __block hasCompleted = NO;
	if(hasCompletedQueue == NULL) {
		return YES;
	}
	__block LPXTTask *weakSelf = self;
    dispatch_sync(hasCompletedQueue, ^{
        hasCompleted = weakSelf->completed;
    });
    return hasCompleted;
}


- (void)cleanupPipes {
    dispatch_sync(pipeAccessQueue, ^{
        [self closePipes];
        [inheritedPipes removeAllObjects];
        [inheritedPipes release];
        inheritedPipes = nil;
        [inheritedPipesMap removeAllObjects];
        [inheritedPipesMap release];
        inheritedPipesMap = nil;
    });
}

- (void)dealloc {
    [arguments release];
	[_environmentVariables release];
    [launchPath release];
    [parentTask release];
    // Submit an empty queue to be sure it's the last one and only
    // release the queue once this has returned.
    dispatch_sync(pipeAccessQueue, ^{});
    dispatch_release(pipeAccessQueue);
    pipeAccessQueue = NULL;
    dispatch_sync(hasCompletedQueue, ^{});
    dispatch_release(hasCompletedQueue);
    hasCompletedQueue = NULL;
    [super dealloc];
}

- (void)closePipes {
    // Close all pipes, otherwise SIGTERM is ignored it seems.
    GPGDebugLog(@"Inherited Pipes: %@", (NSArray *)inheritedPipes);
    for(NSPipe *pipe in (NSArray *)inheritedPipes) {
        @try {
            [[pipe fileHandleForReading] closeFile];
            [[pipe fileHandleForWriting] closeFile];
        }
        @catch (NSException *e) {
            // Simply ignore.
        }
    }
}

- (void)cancel {
	if (processIdentifier > 0) {
        // Close all pipes, otherwise SIGTERM is ignored it seems.
        [self closePipes];
		kill(processIdentifier, SIGTERM);
	}
}

@end
