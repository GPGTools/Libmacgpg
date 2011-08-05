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

#import "GPGTask.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"
#import "LPXTTask.h"
//#import <sys/shm.h>

@interface GPGTask (Private)

+ (void)initializeStatusCodes;
- (NSString *)getPassphraseFromPinentry;
- (void)_writeInputData;

@end


@implementation GPGTask

NSString *_gpgPath;
NSDictionary *statusCodes;

static NSString *GPG_STATUS_PREFIX = @"[GNUPG:] ";
@synthesize isRunning, batchMode, getAttributeData, delegate, userInfo, exitcode, errorCode, gpgPath, outData, errData, statusData, attributeData, lastUserIDHint, lastNeedPassphrase, cancelled,
            gpgTask, verbose;

- (NSArray *)arguments {
	return [[arguments copy] autorelease];
}


- (void)addInData:(NSData *)data {
	if (!inDatas) {
		inDatas = [[NSMutableArray alloc] initWithCapacity:1];
	}
	[inDatas addObject:data];
}
- (void)addInText:(NSString *)string {
	[self addInData:[string gpgData]];
}

- (NSString *)outText {
	if (!outText) {
        outText = [[outData gpgString] retain];
	}
	return [[outText retain] autorelease];
}
- (NSString *)errText {
	if (!errText) {
		errText = [[errData gpgString] retain];
	}
	return [[errText retain] autorelease];
}
- (NSString *)statusText {
	if (!statusText) {
		statusText = [[statusData gpgString] retain];
	}
	return [[statusText retain] autorelease];
}


+ (void)initialize {
	_gpgPath = [self findExecutableWithName:@"gpg2"];
	if (_gpgPath) {
	} else {
		_gpgPath = [self findExecutableWithName:@"gpg"];
		if (!_gpgPath) {
			@throw [NSException exceptionWithName:GPGTaskException reason:localizedLibmacgpgString(@"GPG not found!") userInfo:nil];
		}
	}
	[_gpgPath retain];
    NSLog(@"GPG_PATH: %@", _gpgPath);

	[self initializeStatusCodes];
}

+ (void)initializeStatusCodes {
	statusCodes = [[NSDictionary alloc] initWithObjectsAndKeys:
				   [NSNumber numberWithInteger:GPG_STATUS_ALREADY_SIGNED], @"ALREADY_SIGNED",
				   [NSNumber numberWithInteger:GPG_STATUS_ATTRIBUTE], @"ATTRIBUTE",
				   [NSNumber numberWithInteger:GPG_STATUS_BACKUP_KEY_CREATED], @"BACKUP_KEY_CREATED",
				   [NSNumber numberWithInteger:GPG_STATUS_BADARMOR], @"BADARMOR",
				   [NSNumber numberWithInteger:GPG_STATUS_BADMDC], @"BADMDC",
				   [NSNumber numberWithInteger:GPG_STATUS_BADSIG], @"BADSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_BAD_PASSPHRASE], @"BAD_PASSPHRASE",
				   [NSNumber numberWithInteger:GPG_STATUS_BEGIN_DECRYPTION], @"BEGIN_DECRYPTION",
				   [NSNumber numberWithInteger:GPG_STATUS_BEGIN_ENCRYPTION], @"BEGIN_ENCRYPTION",
				   [NSNumber numberWithInteger:GPG_STATUS_BEGIN_SIGNING], @"BEGIN_SIGNING",
				   [NSNumber numberWithInteger:GPG_STATUS_BEGIN_STREAM], @"BEGIN_STREAM",
				   [NSNumber numberWithInteger:GPG_STATUS_CARDCTRL], @"CARDCTRL",
				   [NSNumber numberWithInteger:GPG_STATUS_DECRYPTION_FAILED], @"DECRYPTION_FAILED",
				   [NSNumber numberWithInteger:GPG_STATUS_DECRYPTION_OKAY], @"DECRYPTION_OKAY",
				   [NSNumber numberWithInteger:GPG_STATUS_DELETE_PROBLEM], @"DELETE_PROBLEM",
				   [NSNumber numberWithInteger:GPG_STATUS_ENC_TO], @"ENC_TO",
				   [NSNumber numberWithInteger:GPG_STATUS_END_DECRYPTION], @"END_DECRYPTION",
				   [NSNumber numberWithInteger:GPG_STATUS_END_ENCRYPTION], @"END_ENCRYPTION",
				   [NSNumber numberWithInteger:GPG_STATUS_END_STREAM], @"END_STREAM",
				   [NSNumber numberWithInteger:GPG_STATUS_ERRMDC], @"ERRMDC",
				   [NSNumber numberWithInteger:GPG_STATUS_ERROR], @"ERROR",
				   [NSNumber numberWithInteger:GPG_STATUS_ERRSIG], @"ERRSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_EXPKEYSIG], @"EXPKEYSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_EXPSIG], @"EXPSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_FILE_DONE], @"FILE_DONE",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_BOOL], @"GET_BOOL",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_HIDDEN], @"GET_HIDDEN",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_LINE], @"GET_LINE",
				   [NSNumber numberWithInteger:GPG_STATUS_GOODMDC], @"GOODMDC",
				   [NSNumber numberWithInteger:GPG_STATUS_GOODSIG], @"GOODSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_GOOD_PASSPHRASE], @"GOOD_PASSPHRASE",
				   [NSNumber numberWithInteger:GPG_STATUS_GOT_IT], @"GOT_IT",
				   [NSNumber numberWithInteger:GPG_STATUS_IMPORTED], @"IMPORTED",
				   [NSNumber numberWithInteger:GPG_STATUS_IMPORT_CHECK], @"IMPORT_CHECK",
				   [NSNumber numberWithInteger:GPG_STATUS_IMPORT_OK], @"IMPORT_OK",
				   [NSNumber numberWithInteger:GPG_STATUS_IMPORT_PROBLEM], @"IMPORT_PROBLEM",
				   [NSNumber numberWithInteger:GPG_STATUS_IMPORT_RES], @"IMPORT_RES",
				   [NSNumber numberWithInteger:GPG_STATUS_INV_RECP], @"INV_RECP",
				   [NSNumber numberWithInteger:GPG_STATUS_INV_SGNR], @"INV_SGNR",
				   [NSNumber numberWithInteger:GPG_STATUS_KEYEXPIRED], @"KEYEXPIRED",
				   [NSNumber numberWithInteger:GPG_STATUS_KEYREVOKED], @"KEYREVOKED",
				   [NSNumber numberWithInteger:GPG_STATUS_KEY_CREATED], @"KEY_CREATED",
				   [NSNumber numberWithInteger:GPG_STATUS_KEY_NOT_CREATED], @"KEY_NOT_CREATED",
				   [NSNumber numberWithInteger:GPG_STATUS_MISSING_PASSPHRASE], @"MISSING_PASSPHRASE",
				   [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE], @"NEED_PASSPHRASE",
				   [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE_PIN], @"NEED_PASSPHRASE_PIN",
				   [NSNumber numberWithInteger:GPG_STATUS_NEED_PASSPHRASE_SYM], @"NEED_PASSPHRASE_SYM",
				   [NSNumber numberWithInteger:GPG_STATUS_NEWSIG], @"NEWSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_NODATA], @"NODATA",
				   [NSNumber numberWithInteger:GPG_STATUS_NOTATION_DATA], @"NOTATION_DATA",
				   [NSNumber numberWithInteger:GPG_STATUS_NOTATION_NAME], @"NOTATION_NAME",
				   [NSNumber numberWithInteger:GPG_STATUS_NO_PUBKEY], @"NO_PUBKEY",
				   [NSNumber numberWithInteger:GPG_STATUS_NO_RECP], @"NO_RECP",
				   [NSNumber numberWithInteger:GPG_STATUS_NO_SECKEY], @"NO_SECKEY",
				   [NSNumber numberWithInteger:GPG_STATUS_NO_SGNR], @"NO_SGNR",
				   [NSNumber numberWithInteger:GPG_STATUS_PKA_TRUST_BAD], @"PKA_TRUST_BAD",
				   [NSNumber numberWithInteger:GPG_STATUS_PKA_TRUST_GOOD], @"PKA_TRUST_GOOD",
				   [NSNumber numberWithInteger:GPG_STATUS_PLAINTEXT], @"PLAINTEXT",
				   [NSNumber numberWithInteger:GPG_STATUS_PLAINTEXT_LENGTH], @"PLAINTEXT_LENGTH",
				   [NSNumber numberWithInteger:GPG_STATUS_POLICY_URL], @"POLICY_URL",
				   [NSNumber numberWithInteger:GPG_STATUS_PROGRESS], @"PROGRESS",
				   [NSNumber numberWithInteger:GPG_STATUS_REVKEYSIG], @"REVKEYSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_RSA_OR_IDEA], @"RSA_OR_IDEA",
				   [NSNumber numberWithInteger:GPG_STATUS_SC_OP_FAILURE], @"SC_OP_FAILURE",
				   [NSNumber numberWithInteger:GPG_STATUS_SC_OP_SUCCESS], @"SC_OP_SUCCESS",
				   [NSNumber numberWithInteger:GPG_STATUS_SESSION_KEY], @"SESSION_KEY",
				   [NSNumber numberWithInteger:GPG_STATUS_SHM_GET], @"SHM_GET",
				   [NSNumber numberWithInteger:GPG_STATUS_SHM_GET_BOOL], @"SHM_GET_BOOL",
				   [NSNumber numberWithInteger:GPG_STATUS_SHM_GET_HIDDEN], @"SHM_GET_HIDDEN",
				   [NSNumber numberWithInteger:GPG_STATUS_SHM_INFO], @"SHM_INFO",
				   [NSNumber numberWithInteger:GPG_STATUS_SIGEXPIRED], @"SIGEXPIRED",
				   [NSNumber numberWithInteger:GPG_STATUS_SIG_CREATED], @"SIG_CREATED",
				   [NSNumber numberWithInteger:GPG_STATUS_SIG_ID], @"SIG_ID",
				   [NSNumber numberWithInteger:GPG_STATUS_SIG_SUBPACKET], @"SIG_SUBPACKET",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUNCATED], @"TRUNCATED",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUST_FULLY], @"TRUST_FULLY",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUST_MARGINAL], @"TRUST_MARGINAL",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUST_NEVER], @"TRUST_NEVER",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUST_ULTIMATE], @"TRUST_ULTIMATE",
				   [NSNumber numberWithInteger:GPG_STATUS_TRUST_UNDEFINED], @"TRUST_UNDEFINED",
				   [NSNumber numberWithInteger:GPG_STATUS_UNEXPECTED], @"UNEXPECTED",
				   [NSNumber numberWithInteger:GPG_STATUS_USERID_HINT], @"USERID_HINT",
				   [NSNumber numberWithInteger:GPG_STATUS_VALIDSIG], @"VALIDSIG",
				   nil];
}


+ (BOOL)isGPGAgentSocket:(NSString *)socketPath {
	socketPath = [socketPath stringByResolvingSymlinksInPath];
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:socketPath error:nil];
	if ([[attributes fileType] isEqualToString:NSFileTypeSocket]) {
		return YES;
	}
	return NO;
}

+ (NSString *)gpgAgentSocket {
	NSString *socketPath = [[GPGOptions sharedOptions] valueForKey:@"GPG_AGENT_INFO" inDomain:GPGDomain_environment];
	NSRange range;
	if (socketPath && (range = [socketPath rangeOfString:@":"]).length > 0) {
		socketPath = [socketPath substringToIndex:range.location - 1];
		if ([self isGPGAgentSocket:socketPath]) {
			return socketPath;
		}
	}
	socketPath = [[[GPGOptions sharedOptions] gpgHome] stringByAppendingPathComponent:@"S.gpg-agent"];
	if ([self isGPGAgentSocket:socketPath]) {
		return socketPath;
	}
	return nil;
}
+ (NSString *)pinentryPath {
	NSString *foundPath = [[GPGOptions sharedOptions] valueForKey:@"pinentry-path" inDomain:GPGDomain_gpgAgentConf];
	foundPath = [foundPath stringByStandardizingPath];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
		foundPath = [self findExecutableWithName:@"../libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac"];
	}
	return foundPath;
}
+ (NSString *)findExecutableWithName:(NSString *)executable {
	NSString *foundPath;
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/bin", @"/usr/local/MacGPG2/bin", @"/usr/local/MacGPG1/bin", @"/usr/bin", @"/bin", @"/opt/local/bin", @"/sw/bin", nil];
	
	foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) {
		return foundPath;
	}
	
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *searchPaths = [envPATH componentsSeparatedByString:@":"];
		foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
		if (foundPath) {
			return foundPath;
		}		
	}
	
	return nil;
}
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths {
	NSString *searchPath, *foundPath;
	for (searchPath in paths) {
		foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return [foundPath stringByStandardizingPath];
		}
	}
	return nil;
}



+ (NSString *)nameOfStatusCode:(NSInteger)statusCode {
	return [[statusCodes allKeysForObject:[NSNumber numberWithInteger:statusCode]] objectAtIndex:0];
}


+ (id)gpgTaskWithArguments:(NSArray *)args batchMode:(BOOL)batch {
	return [[[self alloc] initWithArguments:args batchMode:batch] autorelease]; 
}
+ (id)gpgTaskWithArguments:(NSArray *)args {
	return [self gpgTaskWithArguments:args batchMode:NO]; 
}
+ (id)gpgTaskWithArgument:(NSString *)arg {
	return [self gpgTaskWithArguments:[NSArray arrayWithObject:arg] batchMode:NO]; 
}
+ (id)gpgTask {
	return [self gpgTaskWithArguments:nil batchMode:NO]; 
}




- (id)initWithArguments:(NSArray *)args batchMode:(BOOL)batch {
	self = [super init];
	if (self) {
		arguments = [[NSMutableArray alloc] initWithArray:args];
		self.gpgPath = _gpgPath;
		batchMode = batch;
	}
	return self;	
}
- (id)initWithArguments:(NSArray *)args {
	return [self initWithArguments:args batchMode:NO];
}
- (id)initWithArgument:(NSString *)arg {
	return [self initWithArguments:[NSArray arrayWithObject:arg] batchMode:NO];
}
- (id)init {
	return [self initWithArguments:nil batchMode:NO];
}



- (void)dealloc {
	[arguments release];
	self.userInfo = nil;
	
	[outData release];
	[errData release];
	[statusData release];
	[attributeData release];
	[outText release];
	[errText release];
	[statusText release];
	[inDatas release];
    //[cmdPipe release];
	
	self.lastUserIDHint = nil;
	self.lastNeedPassphrase = nil;
	
	self.gpgPath = nil;
	
	[super dealloc];
}




- (void)addArgument:(NSString *)arg {
	[arguments addObject:arg];
}
- (void)addArguments:(NSArray *)args {
	[arguments addObjectsFromArray:args];
}


- (NSInteger)start {	
	isRunning = YES;
	
    // Default arguments which every call to GPG needs.
    NSMutableArray *defaultArguments = [[NSMutableArray alloc] initWithObjects:
                                        @"--no-greeting", @"--no-tty", @"--with-colons",
                                        @"--yes", @"--output", @"-", nil];
    // Add GPG 1 arguments.
    [defaultArguments addObject:@"--fixed-list-mode"];
    //[defaultArguments addObject:@"--use-agent"];
    // Add the status fd.
    [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--status-fd", @"3", nil]];
    // If batch mode is not set, add the command-fd using stdin.
    if(batchMode)
        [defaultArguments addObject:@"--batch"];
    else
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--no-batch", @"--command-fd", @"0", nil]];
    // If the attribute data is required, add the attribute-fd.
    if(getAttributeData)
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--attribute-fd", @"4", nil]];
    // TODO: Optimize and make more generic.
    //Für Funktionen wie --decrypt oder --verify sollte "--no-armor" nicht gesetzt sein.
    // Last before launching, create the inPipes and add the fd nums to the arguments.
    if ([arguments containsObject:@"--no-armor"] || [arguments containsObject:@"--no-armour"]) {
        NSSet *inputParameters = [NSSet setWithObjects:@"--decrypt", @"--verify", @"--import", nil];
        for (NSString *argument in arguments) {
            if ([inputParameters containsObject:argument]) {
                NSUInteger index = [arguments indexOfObject:@"--no-armor"];
                if (index == NSNotFound) {
                    index = [arguments indexOfObject:@"--no-armour"];
                }
                [arguments replaceObjectAtIndex:index withObject:@"--armor"];
                
                while ((index = [arguments indexOfObject:@"--no-armor"]) != NSNotFound) {
                    [arguments removeObjectAtIndex:index];
                }
                while ((index = [arguments indexOfObject:@"--no-armour"]) != NSNotFound) {
                    [arguments removeObjectAtIndex:index];
                }
                break;
            }
        }
    }
    [defaultArguments addObjectsFromArray:arguments];
    // Last but not least, add the fd's used to read the in-data from.
    int i = 5;
    for(NSData *data in inDatas) {
        [defaultArguments addObject:[NSString stringWithFormat:@"/dev/fd/%d", i++]];
    }
    
    if([delegate respondsToSelector:@selector(gpgTaskWillStart:)]) {
        [delegate gpgTaskWillStart:self];
    }
    
    // Allow the target to abort.
    if (cancelled)
		return GPGErrorCancelled;
    
    gpgTask = [[LPXTTask alloc] init];
    gpgTask.launchPath = self.gpgPath;
    gpgTask.standardInput = [NSPipe pipe];
    gpgTask.standardOutput = [NSPipe pipe];
    gpgTask.standardError = [NSPipe pipe];
    gpgTask.arguments = defaultArguments;
    [defaultArguments release];
    
    if(self.verbose)
        NSLog(@"gpg %@", [gpgTask.arguments componentsJoinedByString:@" "]);
    
    // Now setup all the pipes required to communicate with gpg.
    [gpgTask inheritPipe:[NSPipe pipe] mode:O_RDONLY dup:3 name:@"status"];
    [gpgTask inheritPipe:[NSPipe pipe] mode:O_RDONLY dup:4 name:@"attribute"];
    NSMutableArray *pipeList = [[NSMutableArray alloc] init];
    NSMutableArray *dupList = [[NSMutableArray alloc] init];
    i = 5;
    for(NSData *data in inDatas) {
        [pipeList addObject:[NSPipe pipe]];
        [dupList addObject:[NSNumber numberWithInt:i++]];
    }
    [gpgTask inheritPipes:pipeList mode:O_WRONLY dups:dupList name:@"ins"];
    //[pipeList release];
    [dupList release];
    // Setup the task to be run in the parent process, before
    // the parent starts waiting for the child.
    NSMutableData *completeStatusData = [[NSMutableData alloc] initWithLength:0];
    
    BOOL localVerbose = self.verbose;
    NSLog(@"Local verbose is: %@", localVerbose ? @"YES" : @"NO");
    gpgTask.parentTask = ^{
        // Setup the dispatch queue.
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        // Create the group which will hold all the jobs which should finish before
        // the parent process starts waiting for the child.
        dispatch_group_t collectorGroup = dispatch_group_create();
        // The data is written to the pipe as soon as gpg issues the status
        // BEGIN_ENCRYPTION. See processStatus.
        // Added: Actually, there seems to be more to it.
        // When data is ENCRYPTED, the data can't be written before the BEGIN_ENCRYPTION
        // status was issued, BUT
        // when data is DECRYPTED, gpg stalls till it received the data to decrypt.
        // So in that case, the data actually has to be written as the very first thing.
        // Beats me I tell you...
        if([gpgTask.arguments containsObject:@"--decrypt"]) {
            dispatch_group_async(collectorGroup, queue, ^{
                // Encrypt only takes one file, more files not supported,
                // so it's not important to check which file's data is required,
                // it's always the first.
                [self _writeInputData];
            });
        }
        // Add each job to the collector group.
        dispatch_group_async(collectorGroup, queue, ^{
            outData = [[[gpgTask inheritedPipeWithName:@"stdout"] fileHandleForReading] readDataToEndOfFile];
            [outData retain];
            if(self.verbose)
                [self logDataContent:outData message:@"[STDOUT]"];
        });
        dispatch_group_async(collectorGroup, queue, ^{
            errData = [[[gpgTask inheritedPipeWithName:@"stderr"] fileHandleForReading] readDataToEndOfFile];
            [errData retain];
            if(self.verbose)
                [self logDataContent:errData message:@"[STDERR]"];
        });
        if(getAttributeData) {
            dispatch_group_async(collectorGroup, queue, ^{
                attributeData = [[[gpgTask inheritedPipeWithName:@"attribute"] fileHandleForReading] readDataToEndOfFile];
                [attributeData retain];
            });
        }
        // Handle the status data. This is an important one.
        dispatch_group_async(collectorGroup, queue, ^{
            NSPipe *statusPipe = [gpgTask inheritedPipeWithName:@"status"];
            NSFileHandle *statusPipeReadingFH = [statusPipe fileHandleForReading];
            NSData *currentData;
            NSMutableString *line = [[NSMutableString alloc] init];
            NSString *linePart;
            NSArray *tmpLines;
            while((currentData = [statusPipeReadingFH availableData]) && [currentData length]) {
                // Add the received data for later use.
                [completeStatusData appendData:currentData];
                // Convert the data to a string, to better work with it.
                linePart = [[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding];
                // Line part might acutally be already multiple lines, in that case, well...
                // the fucker is split up and processKeyword:value: called for each line.
                tmpLines = [linePart componentsSeparatedByString:@"\n"];
                [linePart release];
                int i = 0;
                for(id tmpLine in tmpLines) {
                    // If multiple lines are found, the last line will be used,
                    // to restart a new line.
                    if(i == 0)
                        tmpLine = [line stringByAppendingString:tmpLine]; 
                    if(i == [tmpLines count] - 1) {
                        [line setString:[tmpLines objectAtIndex:[tmpLines count]-1]];
                        break;
                    }
                    [self processStatusLine:tmpLine];
                    i++;
                }
                // Unfortunately we never know if enough data has come in yet to parse.
                // So, until a \n character is found, we're appending the data.
                //[line appendString:linePart];
                if(((NSRange)[line rangeOfString:@"\n"]).location == NSNotFound)
                    continue;
                [line replaceCharactersInRange:[line rangeOfString:@"\n"] withString:@""];
                // Skip the lines that don't begin with [GNUPG:].
                if(((NSRange)[line rangeOfString:GPG_STATUS_PREFIX]).location == NSNotFound)
                    continue;
                // Parse the keyword and value, and process.
                [self processStatusLine:line];
                // Reset line.
                [line setString:@""];
            }
            [line release];
        });
        
        // Wait for the jobs to finish.
        dispatch_group_wait(collectorGroup, DISPATCH_TIME_FOREVER);
        // And release the dispatch queue.
        dispatch_release(collectorGroup);
        
        if(self.verbose)
            [self logDataContent:statusData message:@"[STATUS]"];
    };
        
    // AAAAAAAAND NOW! Let's run the task and wait for it to complete.
    [gpgTask launchAndWait];
    
    exitcode = gpgTask.terminationStatus;
    
    // For some wicked reason gpg exits with status > 0 if a signature
    // fails to validate.
    if(exitcode != 0 && passphraseStatus == 4 && !cancelled)
        return 0;
    
    if(cancelled)
        exitcode = GPGErrorCancelled;
    
    // Add some error handling here...
    // Close all open pipes by releasing the gpgTask.
    [gpgTask release];
    
    if([delegate respondsToSelector:@selector(gpgTaskDidTerminate:)])
        [delegate gpgTaskDidTerminate:self];
    
    isRunning = NO;
    
    return exitcode;
}

- (void)_writeInputData {
    NSArray *pipeList = [gpgTask inheritedPipesWithName:@"ins"];
    for(int i = 0; i < [pipeList count]; i++) {
        [[[pipeList objectAtIndex:i] fileHandleForWriting] writeData:[inDatas objectAtIndex:i]];
        [[[pipeList objectAtIndex:i] fileHandleForWriting] closeFile];
    }
}
- (void)processStatusLine:(NSString *)line {
    NSString *keyword;
    NSString *value;
    line = [line stringByReplacingOccurrencesOfString:GPG_STATUS_PREFIX withString:@""];
    if(self.verbose)
        NSLog(@">> %@", line);
    NSMutableArray *parts = [[line componentsSeparatedByString:@" "] mutableCopy];
    keyword = [parts objectAtIndex:0];
    if([parts count] > 1) {
        [parts removeObjectAtIndex:0];
        value = [parts componentsJoinedByString:@" "];
    }
    else
        value = [NSString stringWithString:@""];
    [parts release];
    
    NSInteger statusCode = [[statusCodes objectForKey:keyword] integerValue];
    // No status code available, we're out of here.
    if(!statusCode)
        return;
    BOOL isPassphraseRequest = NO;
    switch(statusCode) {
        case GPG_STATUS_USERID_HINT: {
            NSRange range = [value rangeOfString:@" "];
            NSString *keyID = [value substringToIndex:range.location];
            NSString *userID = [value substringFromIndex:range.location + 1];
            self.lastUserIDHint = [NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", userID, @"userID", nil];
            passphraseStatus = 1;
            break;
        }
        case GPG_STATUS_NEED_PASSPHRASE: {
            NSArray *components = [value componentsSeparatedByString:@" "];
            self.lastNeedPassphrase = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [components objectAtIndex:0], @"mainKeyID", 
                                       [components objectAtIndex:1], @"keyID", 
                                       [components objectAtIndex:2], @"keyType", 
                                       [components objectAtIndex:3], @"keyLength", nil];
            passphraseStatus = 1;
            break;
        }
        case GPG_STATUS_GOOD_PASSPHRASE:
            passphraseStatus = 4;
            break;
        case GPG_STATUS_BAD_PASSPHRASE: {
            self.lastUserIDHint = nil;
            self.lastNeedPassphrase = nil;
            passphraseStatus = 2;
            break;
        }
        case GPG_STATUS_MISSING_PASSPHRASE:
            self.lastUserIDHint = nil;
            self.lastNeedPassphrase = nil;
            passphraseStatus = 3;
            break;
        case GPG_STATUS_GET_HIDDEN:
            if([value isEqualToString:@"passphrase.enter"])
                isPassphraseRequest = YES;
            break;
        case GPG_STATUS_ERROR: {
            NSRange range = [value rangeOfString:@" "];
            if(range.length > 0)
                errorCode = [[value substringFromIndex:range.location + 1] intValue];
            break;
        }
        case GPG_STATUS_BEGIN_ENCRYPTION: {
            // Encrypt only takes one file, more files not supported,
            // so it's not important to check which file's data is required,
            // it's always the first.
            [self _writeInputData];
            break;
        }
        case GPG_STATUS_BEGIN_SIGNING: {
            [self _writeInputData];
            break;
        }
    }
    id returnValue;
    if([delegate respondsToSelector:@selector(gpgTask:statusCode:prompt:)]) {
        returnValue = [delegate gpgTask:self statusCode:statusCode prompt:value];
    }
    
    // Get the passphrase from the pinetry if gpg asks for it.
    if(isPassphraseRequest) {
        if(!returnValue) {
            returnValue = [self getPassphraseFromPinentry];
            if(returnValue)
                returnValue = [NSString stringWithFormat:@"%@\n", returnValue];
        }
        self.lastUserIDHint = nil;
        self.lastNeedPassphrase = nil;
    }
    
    // Write the return value to the command pipe.
    if(!cmdPipe)
        cmdPipe = [gpgTask inheritedPipeWithName:@"stdin"];
    // Try to write
    if(cmdPipe != nil) {
        if(returnValue) {
            NSData *dataToWrite;
            if([returnValue isKindOfClass:[NSData class]])
                dataToWrite = returnValue;
            else
                dataToWrite = [[returnValue description] dataUsingEncoding:NSUTF8StringEncoding];
            [[cmdPipe fileHandleForWriting] writeData:dataToWrite];
        }
        else if (statusCode == GPG_STATUS_GET_BOOL || statusCode == GPG_STATUS_GET_HIDDEN ||
                 statusCode == GPG_STATUS_GET_LINE) {
            [[cmdPipe fileHandleForWriting] closeFile];
            // Remove the pipe from the task so we can't write to it again.
            [gpgTask removeInheritedPipeWithName:@"stdin"];
            cmdPipe = nil;
        }
    }
}

/* Helper function to display NSData content. */
- (void)logDataContent:(NSData *)data message:(NSString *)message {
    NSString *tmpString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"[DEBUG] %@: %@ >>", message, tmpString);
    [tmpString release];
}

- (void)cancel {
	cancelled = YES;
	if (childPID) {
		kill(childPID, SIGTERM);
	}
}

- (NSString *)getPassphraseFromPinentry {
	NSPipe *inPipe = [NSPipe pipe];
	NSPipe *outPipe = [NSPipe pipe];
	NSTask *pinentryTask = [[NSTask new] autorelease];
	
	NSString *pinentryPath = [[self class] pinentryPath];
	NSAssert(pinentryPath, @"pinentry-mac not found.");
	pinentryTask.launchPath = pinentryPath;
	
	pinentryTask.standardInput = inPipe;
	pinentryTask.standardOutput = outPipe;

	
	
		
	NSString *keyID = [lastNeedPassphrase objectForKey:@"keyID"];
	NSString *mainKeyID = [lastNeedPassphrase objectForKey:@"mainKeyID"];
	NSString *userID = [lastUserIDHint objectForKey:@"userID"];
	//NSString *keyLength = [lastNeedPassphrase objectForKey:@"keyLength"];
	//NSString *keyType = [lastNeedPassphrase objectForKey:@"keyType"];
	
	NSString *description;
	if ([keyID isEqualToString:mainKeyID]) {
		description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription"), 
					   userID, getShortKeyID(keyID)];
	} else {
		description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription_Subkey"), 
					   userID, getShortKeyID(keyID), getShortKeyID(mainKeyID)];
	}
	description = [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *prompt = [localizedLibmacgpgString(@"PassphraseLabel") stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	NSString *inText = [NSString stringWithFormat:@"OPTION grab\n"
						"OPTION cache-id=%@\n"
						"SETDESC %@\n"
						"SETPROMPT %@\n"
						"GETPIN\n"
						"BYE\n", 
						keyID, 
						description, 
						prompt];
	
	NSData *inData = [inText gpgData];
	[[inPipe fileHandleForWriting] writeData:inData];
	
	
	
	
	[pinentryTask launch];
	NSData *output = [[outPipe fileHandleForReading] readDataToEndOfFile];
	[pinentryTask waitUntilExit];
	
	if (!output) {
		@throw gpgException(GPGException, @"Pinentry error!", GPGErrorPINEntryError);
	}
	NSString *outString = [output gpgString];
	
	NSRange range;
	range = [outString rangeOfString:@"\nERR "];
	if (range.length > 0) {
		range.location++; 
		range.length--;
		range = [outString lineRangeForRange:range];
		range.location += 4;
		range.length -= 5;
		NSRange spaceRange = [outString rangeOfString:@" " options:NSLiteralSearch range:range];
		if (spaceRange.length > 0) {
			range.length = spaceRange.location - range.location;
		}
		if ([[outString substringWithRange:range] integerValue] == 0x5000063) {
			[self cancel];
		} else {
			@throw gpgException(GPGException, @"Pinentry error!", GPGErrorPINEntryError);
		}
		return nil;
	}
	
	range = [outString rangeOfString:@"\nD "];
	if (range.length == 0) {
		return @"";
	}
	
	range.location++;
	range.length--;
	range = [outString lineRangeForRange:range];
	range.location += 2;
	range.length -= 3;
	
	if (range.length <= 0) {
		return @"";
	}
	
	return [[outString substringWithRange:range] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

@end



