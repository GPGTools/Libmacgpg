/*
 Copyright © Lukas Pitschl, 2014
 
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
    const NSUInteger argCount = [arguments count];
	NSUInteger i;
	char *args[argCount + 2];
	
	args[0] = (char*)[launchPath UTF8String];
	for (i = 0; i < argCount; i++) {
		args[i+1] = (char*)[[arguments objectAtIndex:i] UTF8String];
	}
	args[argCount + 1] = NULL;
	
	
	
	
	// Add environment variables if needed.
	
	char **newEnviron = *_NSGetEnviron();
	if (_environmentVariables) {
		char **oldEnviron = newEnviron;
		char **tempEnviron = oldEnviron;
		
		NSUInteger envCount = _environmentVariables.count;
		NSUInteger environCount = 0;
		
		while (*tempEnviron) {
			environCount++;
			tempEnviron++;
		}
		
		newEnviron = malloc((envCount + environCount + 1) * sizeof(char **));
		if (!newEnviron) {
			NSLog(@"launchAndWait malloc failed!");
			return;
		}
		memcpy(newEnviron, oldEnviron, (environCount + 1) * sizeof(char **));
		
		i = environCount;
		for (NSString *key in _environmentVariables) {
			NSString *value = [_environmentVariables objectForKey:key];
			
			char *envVar = (char *)[[NSString stringWithFormat:@"%@=%@", key, value] UTF8String];
			NSUInteger cmpLength = key.length + 1;
			
			tempEnviron = newEnviron;
			while (*tempEnviron) { // Search an existing env var with the same name.
				if (strncmp(*tempEnviron, envVar, cmpLength) == 0) {
					*tempEnviron = envVar;
					
					tempEnviron = nil;
					break;
				}
				tempEnviron++;
			}

			if (tempEnviron) { // No env var with the same name found, add a new at the end.
				newEnviron[i] = envVar;
				i++;
				newEnviron[i] = 0;
			}
		}
	}
	
	

	
    
    // Add the stdin, stdout and stderr to the inherited pipes, so all of them can be
    // processed together.
	[self inheritPipeWithMode:O_WRONLY dup:0 name:@"stdin"];
	[self inheritPipeWithMode:O_RDONLY dup:1 name:@"stdout"];
	[self inheritPipeWithMode:O_RDONLY dup:2 name:@"stderr"];
	
    
    // File descriptors to close in the parent process.
    NSMutableSet *closeInParent = [NSMutableSet set];
	
    // File descriptors to close in the child process.
    int pipeCount = (int)inheritedPipes.count;
    lpxttask_fd fds[pipeCount];
    for(i = 0; i < pipeCount; i++) {
        fds[i].fd = -1;
        fds[i].dupfd = -1;
    }
    
    NSPipe *tmpPipe;
    int k = 0;
    NSMutableArray *fdArray = [NSMutableArray array];
    for(id key in inheritedPipesMap) {
        NSArray *pipeList = [inheritedPipesMap objectForKey:key];
        for(NSDictionary *pipeInfo in pipeList) {
            NSNumber *idx = [pipeInfo valueForKey:@"pipeIdx"];
            
            tmpPipe = [inheritedPipes objectAtIndex:[idx intValue]];
            // The mode value of the pipe decides what should happen with the
            // pipe fd of the parent. Opposite with the fd of the child.
            if([[pipeInfo valueForKey:@"mode"] intValue] == O_RDONLY) {
                [closeInParent addObject:[tmpPipe fileHandleForWriting]];
                [fdArray addObject:
                 [NSMutableArray arrayWithObjects:[NSNumber numberWithInt:[[tmpPipe fileHandleForWriting] fileDescriptor]],
                  [pipeInfo valueForKey:@"dupfd"], nil]];
            }
            else {
                [closeInParent addObject:[tmpPipe fileHandleForReading]];
                [fdArray addObject:
                 [NSMutableArray arrayWithObjects:[NSNumber numberWithInt:[[tmpPipe fileHandleForReading] fileDescriptor]],
                  [pipeInfo valueForKey:@"dupfd"], nil]];
            }
            k++;
        }
    }
    [fdArray sortUsingComparator:^NSComparisonResult(id a, id b){
        if([[a objectAtIndex:0] isLessThan:[b objectAtIndex:0]])
            return NSOrderedAscending;
        else if([[b objectAtIndex:0] isLessThan:[a objectAtIndex:0]])
            return NSOrderedDescending;
        else
            return NSOrderedSame;
    }];
    
    for(i = 0; i < [fdArray count]; i++) {
        fds[i].fd = [[[fdArray objectAtIndex:i] objectAtIndex:0] intValue];
        fds[i].dupfd = [[[fdArray objectAtIndex:i] objectAtIndex:1] intValue];
    }
    
    // Avoid the parent to proceed, before the child is running.
    int blockpipe[2] = { -1, -1 };
    if (pipe(blockpipe))
        perror("failed to create blockpipe");
    
    // To find the fds wich are acutally open, it would be possibe to
    // read /dev/fd entries. But not sure if that's a problem, so let's
    // use BDSKTask's version.
    rlim_t maxOpenFiles = OPEN_MAX;
    struct rlimit openFileLimit;
    if (getrlimit(RLIMIT_NOFILE, &openFileLimit) == 0)
        maxOpenFiles = openFileLimit.rlim_cur;
    
    // !!! No CF or Cocoa after this point in the child process!
    processIdentifier = fork();
    
    if(processIdentifier == 0) {
        // This is the child.
        
        // set process group for killpg()
        (void)setpgid(getpid(), getpid());
        
        for(i = 0; i < pipeCount; i++) {
            // If dupfd is set, close invoke dup2. This closes
            // the original fd and duplicates to the new fd.
            if(fds[i].fd > -1 && fds[i].dupfd > -1) {
                dup2(fds[i].fd, fds[i].dupfd);
            }
        }
        
        // Just for testing.
        int do_close = 1;
        for (rlim_t j = 0; j < maxOpenFiles; j++) {
            do_close = 1;
            for(i = 0; i < pipeCount; i++) {
                if((unsigned)fds[i].dupfd == j || (unsigned)fds[i].fd == j) {
                    do_close = 0;
                }
            }
            
            if(do_close && (unsigned)blockpipe[0] != j && j != 1)
                close((int)j);
        }
        
        
        char ignored;
        // block until the parent has setup complete
        read(blockpipe[0], &ignored, 1);
        close(blockpipe[0]);
        
        // AAAAAAND run our command.
		//int ret = execv(args[0], args);
        int ret = execve(args[0], args, newEnviron);
        _exit(ret);
    }
    else if (processIdentifier == -1) {
        // parent: error
        perror("fork() failed");
        terminationStatus = 2;
    }
    else {
        // This is the parent.
        // Close the fd's in the parent.
        [closeInParent makeObjectsPerformSelector:@selector(closeFile)];
        
        // all setup is complete, so now widow the pipe and exec in the child
        close(blockpipe[0]);   
        close(blockpipe[1]);
        
        // Run the task setup to run in the parent.
		if(parentTask != nil) {
			parentTask();
		}
        
        // Wait for the gpg process to finish.
        int retval, stat_loc;
        while ((retval = waitpid(processIdentifier, &stat_loc, 0)) != processIdentifier) {
            int e = errno;
            if (retval != -1 || e != EINTR) {
                GPGDebugLog(@"waitpid loop: %i errno: %i, %s", retval, e, strerror(e));
            }
        }
        if (WIFEXITED(stat_loc)) {
            GPGDebugLog(@"[%d] normal termination, exit status = %d\n", processIdentifier, WEXITSTATUS(stat_loc));
        }
        else if (WIFSIGNALED(stat_loc)) {
            GPGDebugLog(@"[%d] abnormal termination, signal number = %d - termination status: %d\n", processIdentifier, WTERMSIG(stat_loc), WEXITSTATUS(stat_loc));
        }
        terminationStatus = WEXITSTATUS(stat_loc);
        // In case that the child process crashes or was killed by a signal,
        // the termination status would still be 0, which is however absolutely misleading.
        // In order to correctly handle these cases, 2 is returned as error status.
        if(WIFSIGNALED(stat_loc))
            terminationStatus = 2;

        self.completed = YES;

        // After running, clean up all the pipes, so no data can be written at this point.
        // Wouldn't make sense anyway, since the child has shutdown already.
        [self cleanupPipes];
    }
    
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
