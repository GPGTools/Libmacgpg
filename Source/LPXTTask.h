//
//  LPXTTask.h
//  Libmacgpg
//
//  Created by Lukas Pitschl on 17.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

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

//- (void)terminate;
//- (void)suspend;
//- (void)resume;

@end
