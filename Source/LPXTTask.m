//
//  LPXTTask.m
//  Libmacgpg
//
//  Created by Lukas Pitschl on 17.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LPXTTask.h"
// Includes definition for _NSGetEnviron
#import <crt_externs.h>

typedef struct {
    int fd;
    int dupfd;
} lpxttask_fd;

@interface LPXTTask ()

- (void)inheritPipe:(NSPipe *)pipe mode:(int)mode dup:(int)dupfd name:(NSString *)name addIfExists:(BOOL)add;
- (void)_performParentTask;

@end

@implementation LPXTTask

@synthesize arguments=_arguments, currentDirectoryPath=_currentDirectoryPath, 
            environment=_environment, launchPath=_launchPath, 
            processIdentifier=_processIdentifier, standardError=_standardError,
            standardInput=_standardInput, standardOutput=_standardOutput,
            terminationStatus=_terminationStatus, parentTask=_parentTask;

- (id)init
{
    self = [super init];
    if(self != nil) {
        _inheritedPipes = CFArrayCreateMutable(NULL, 0, NULL);
        _inheritedPipesMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

/*
 Undocumented behavior of -[NSFileManager fileSystemRepresentationWithPath:]
 is to raise an exception when passed an empty string.  Since this is called by
 -[NSString fileSystemRepresentation], use CF.  rdar://problem/9565599
 
 https://bitbucket.org/jfh/machg/issue/244/p1d3-crash-during-view-differences
 
 Have to copy all -[NSString fileSystemRepresentation] pointers to avoid garbage collection
 issues with -fileSystemRepresentation, anyway.  How tedious compared to -autorelease...
 
 http://lists.apple.com/archives/objc-language/2011/Mar/msg00122.html
 */
static char *__BDSKCopyFileSystemRepresentation(NSString *str)
{
    if (nil == str) return NULL;
    
    CFIndex len = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)str);
    char *cstr = NSZoneCalloc(NSDefaultMallocZone(), len, sizeof(char));
    if (CFStringGetFileSystemRepresentation((CFStringRef)str, cstr, len) == FALSE) {
        NSZoneFree(NSDefaultMallocZone(), cstr);
        cstr = NULL;
    }
    return cstr;
}

- (void)launchAndWait {
    // This launch method is partly taken from BDSKTask.
    const NSUInteger argCount = [_arguments count];
    char *workingDir = __BDSKCopyFileSystemRepresentation(_currentDirectoryPath);
    
    // fill with pointers to copied C strings
    char **args = NSZoneCalloc([self zone], (argCount + 2), sizeof(char *));
    NSUInteger i;
    args[0] = __BDSKCopyFileSystemRepresentation(_launchPath);
    for (i = 0; i < argCount; i++) {
        args[i + 1] = __BDSKCopyFileSystemRepresentation([_arguments objectAtIndex:i]);
    }
    args[argCount + 1] = NULL;
    
    char ***nsEnvironment = (char ***)_NSGetEnviron();
    char **env = *nsEnvironment;
    
    NSDictionary *environment = [self environment];
    if (environment) {
        // fill with pointers to copied C strings
        env = NSZoneCalloc([self zone], [environment count] + 1, sizeof(char *));
        NSString *key;
        NSUInteger envIndex = 0;
        for (key in environment) {
            env[envIndex++] = __BDSKCopyFileSystemRepresentation([NSString stringWithFormat:@"%@=%@", key, [environment objectForKey:key]]);        
        }
        env[envIndex] = NULL;
    }
    // Add the stdin, stdout and stderr to the inherited pipes, so all of them can be
    // processed together.
    if([_standardInput isKindOfClass:[NSPipe class]])
        [self inheritPipe:_standardInput mode:O_WRONLY dup:0 name:@"stdin"];
    if([_standardOutput isKindOfClass:[NSPipe class]])
        [self inheritPipe:_standardOutput mode:O_RDONLY dup:1 name:@"stdout"];
    if([_standardError isKindOfClass:[NSPipe class]])
        [self inheritPipe:_standardError mode:O_RDONLY dup:2 name:@"stderr"];
    
    // File descriptors to close in the parent process.
    NSMutableSet *closeInParent = [NSMutableSet set];
    // Based on BDSKTask's believe, no Cocoa or CF calls should be used in 
    // the child process.
    // Not sure for what reason, but let's comply with that.
    // File descriptors to close in the child process.
    lpxttask_fd fds[CFArrayGetCount(_inheritedPipes)];
    for(int i = 0; i < CFArrayGetCount(_inheritedPipes); i++) {
        fds[i].fd = -1;
        fds[i].dupfd = -1;
    }
    
    NSPipe *tmpPipe;
    int k = 0;
    NSMutableArray *fdArray = [NSMutableArray array];
    for(id key in _inheritedPipesMap) {
        NSArray *pipeList = [_inheritedPipesMap objectForKey:key];
        for(NSDictionary *pipeInfo in pipeList) {
            NSNumber *idx = [pipeInfo valueForKey:@"pipeIdx"];
            
            tmpPipe = (NSPipe *)CFArrayGetValueAtIndex(_inheritedPipes, [idx intValue]);
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
    
    for(int i = 0; i < [fdArray count]; i++) {
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
    
    int pipeCount = CFArrayGetCount(_inheritedPipes);
    
    
    // !!! No CF or Cocoa after this point in the child process!
    _processIdentifier = fork();
    
    if(_processIdentifier == 0) {
        // This is the child.
        
        // set process group for killpg()
        (void)setpgid(getpid(), getpid());
        
        for(int i = 0; i < pipeCount; i++) {
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
            for(int i = 0; i < pipeCount; i++) {
                if((unsigned)fds[i].dupfd == j || (unsigned)fds[i].fd == j) {
                    do_close = 0;
                }
            }
            
            if(do_close && (unsigned)blockpipe[0] != j && j != 1)
                close(j);
        }
        
        // Change the working dir.
        if (workingDir) chdir(workingDir);
        
        char ignored;
        // block until the parent has setup complete
        read(blockpipe[0], &ignored, 1);
        close(blockpipe[0]);
        
        // AAAAAAND run our command.
        int ret = execve(args[0], args, env);
        _exit(ret);
    }
    else if (_processIdentifier == -1) {
        // parent: error
        perror("fork() failed");
        _terminationStatus = 2;
    }
    else {
        // This is the parent.
        // Close the fd's in the parent.
        [closeInParent makeObjectsPerformSelector:@selector(closeFile)];
        
        // all setup is complete, so now widow the pipe and exec in the child
        close(blockpipe[0]);   
        close(blockpipe[1]);
        
        // Run the task setup to run in the parent.
        [self _performParentTask];
        
        // Wait for the gpg process to finish.
        int retval, stat_loc;
        while ((retval = waitpid(_processIdentifier, &stat_loc, 0)) != _processIdentifier) {
            int e = errno;
            if (retval != -1 || e != EINTR) {
                NSLog(@"waitpid loop: %i errno: %i, %s", retval, e, strerror(e));
            }
        }
        _terminationStatus = WEXITSTATUS(stat_loc);
    }
    
    /*
     Free all the copied C strings.  Don't modify the base pointer of args or env, since we have to
     free those too!
     */
    free(workingDir);
    char **freePtr = args;
    while (NULL != *freePtr) { 
        free(*freePtr++);
    }
    
    NSZoneFree(NSZoneFromPointer(args), args);
    if (*nsEnvironment != env) {
        freePtr = env;
        while (NULL != *freePtr) { 
            free(*freePtr++);
        }
        NSZoneFree(NSZoneFromPointer(env), env);
    }
}

- (void)_performParentTask {
    if(_parentTask != nil) {
        _parentTask();
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
- (void)inheritPipe:(NSPipe *)pipe mode:(int)mode dup:(int)dupfd name:(NSString *)name addIfExists:(BOOL)addIfExists {
    // Create a dictionary holding additional information about the pipe.
    // This info is used later to close and dup the file descriptor which
    // is used by either parent or child.
    NSMutableDictionary *pipeInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:mode], @"mode",
                                     [NSNumber numberWithInt:dupfd], @"dupfd", nil];
    // Add the pipe to the _inheritedPipes array.
    // A CFMutableArray is used instead of a NSMutableArray due to the fact,
    // that NSMutableArrays copy added values and CFMutableArrays only retain them.
    CFArrayAppendValue(_inheritedPipes, pipe);
    [pipeInfo setValue:[NSNumber numberWithInt:CFArrayGetCount(_inheritedPipes)-1] forKey:@"pipeIdx"];
    // The pipe info is add to the pipe maps.
    // If a pipe already exists under that name, it's added to the list of pipes the
    // name is referring to.
    NSMutableArray *pipeList = (NSMutableArray *)[_inheritedPipesMap valueForKey:name];
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
    if([pipeList count] == 1)
        [_inheritedPipesMap setValue:pipeList forKey:name];
}

- (void)inheritPipe:(NSPipe *)pipe mode:(int)mode dup:(int)dupfd name:(NSString *)name {
    // Raise an error if the pipe already exists.
    [self inheritPipe:pipe mode:mode dup:dupfd name:name addIfExists:NO];
}

- (void)inheritPipes:(NSArray *)pipes mode:(int)mode dups:(NSArray *)dupfds name:(NSString *)name {
    NSAssert([pipes count] == [dupfds count], @"Number of pipes and fds to duplicate not matching!");
    
    for(int i = 0; i < [pipes count]; i++) {
        [self inheritPipe:[pipes objectAtIndex:i] mode:mode dup:[[dupfds objectAtIndex:i] intValue] name:name addIfExists:YES];
    }
}

- (NSArray *)inheritedPipesWithName:(NSString *)name {
    // Find the pipe info matching the given name.
    NSDictionary *pipeInfo = [_inheritedPipesMap valueForKey:name];
    CFMutableArrayRef pipeList = CFArrayCreateMutable(NULL, 0, NULL);
    for(id idx in [pipeInfo valueForKey:@"pipeIdx"])
        CFArrayAppendValue(pipeList, CFArrayGetValueAtIndex(_inheritedPipes, [idx intValue]));
    return [(NSArray *)pipeList autorelease];
}

- (NSPipe *)inheritedPipeWithName:(NSString *)name {
    NSArray *pipeList = [self inheritedPipesWithName:name];
    // If there's no pipe registered for that name, raise an error.
    if(![pipeList count] && pipeList != nil)
        @throw [NSException exceptionWithName:@"NoPipeRegisteredUnderNameException" 
                                       reason:[NSString stringWithFormat:@"There's no pipe registered for name: %@", name] 
                                     userInfo:nil];
    return [pipeList objectAtIndex:0];
}

- (void)removeInheritedPipeWithName:(NSString *)name {
    // Find the pipeInfo.
    NSArray *pipeList = [_inheritedPipesMap objectForKey:name];
    for(NSDictionary *pipeInfo in pipeList) {
        NSNumber *idx = [pipeInfo objectForKey:@"pipeIdx"];
        CFArrayRemoveValueAtIndex(_inheritedPipes, [idx intValue]);
    }
    [pipeList release];
    [_inheritedPipesMap setValue:nil forKey:name];
}

- (void)dealloc {
    [_arguments release];
    [_currentDirectoryPath release];
    [_environment release];
    [_launchPath release];
    [_standardError release];
    [_standardInput release];
    [_standardOutput release];
    [_parentTask release];
    CFRelease(_inheritedPipes);
    [_inheritedPipesMap release];
    [super dealloc];
}

@end
