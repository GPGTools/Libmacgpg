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
#import "GPGMemoryStream.h"
#import "GPGException.h"
#import "GPGGlobals.h"
//#import <sys/shm.h>
#import <fcntl.h>

static const NSUInteger kDataBufferSize = 65536; 

// a little category to fcntl F_SETNOSIGPIPE on each fd
@interface NSPipe (SetNoSIGPIPE)
- (NSPipe *)noSIGPIPE;
@end

@interface GPGTask ()

@property (retain) NSData *errData;
@property (retain) NSData *statusData;
@property (retain) NSData *attributeData;
@property int errorCode;

+ (void)initializeStatusCodes;
- (NSString *)getPassphraseFromPinentry;
- (void)_writeInputData;
- (void)unsetErrorCode:(int)value;

@end


@implementation GPGTask

NSString *_gpgPath;
NSString *_pinentryPath = nil;
NSDictionary *statusCodes;
char partCountForStatusCode[GPG_STATUS_COUNT];

static NSString *GPG_STATUS_PREFIX = @"[GNUPG:] ";
@synthesize isRunning, batchMode, getAttributeData, delegate, userInfo, exitcode, errorCode, gpgPath, errData, statusData, attributeData, lastUserIDHint, lastNeedPassphrase, cancelled,
            gpgTask, progressInfo, statusDict;
@synthesize outStream;



- (NSArray *)arguments {
	return [[arguments copy] autorelease];
}

- (NSData *)outData {
    return [outStream readAllData];
}

- (void)addInput:(GPGStream *)stream
{
	if (!inDatas) 
		inDatas = [[NSMutableArray alloc] init];
	[inDatas addObject:stream];
}
- (void)addInData:(NSData *)data {
    [self addInput:[GPGMemoryStream memoryStreamForReading:data]];
}
- (void)addInText:(NSString *)string {
	[self addInData:[string UTF8Data]];
}

- (NSString *)outText {
	if (!outText) {
        outText = [[[outStream readAllData] gpgString] retain];
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
	if (!_gpgPath) {
		_gpgPath = [self findExecutableWithName:@"gpg"];
	}
	[_gpgPath retain];
    GPGDebugLog(@"GPG: %@", _gpgPath);
	
	[self pinentryPath];
    GPGDebugLog(@"Pinentry: %@", [self pinentryPath]);
	
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
	
	
	
	//Status codes where the last part can contain withespaces.
	memset(partCountForStatusCode, 0, sizeof(partCountForStatusCode));
	partCountForStatusCode[GPG_STATUS_EXPKEYSIG] = 2;
	partCountForStatusCode[GPG_STATUS_EXPSIG] = 2;
	partCountForStatusCode[GPG_STATUS_GOODSIG] = 2;
	partCountForStatusCode[GPG_STATUS_IMPORTED] = 2;
	partCountForStatusCode[GPG_STATUS_IMPORT_CHECK] = 3;
	partCountForStatusCode[GPG_STATUS_INV_RECP] = 2;
	partCountForStatusCode[GPG_STATUS_INV_SGNR] = 2;
	partCountForStatusCode[GPG_STATUS_NOTATION_DATA] = 1;
	partCountForStatusCode[GPG_STATUS_NOTATION_NAME] = 1;
	partCountForStatusCode[GPG_STATUS_NO_RECP] = 1;
	partCountForStatusCode[GPG_STATUS_NO_SGNR] = 1;
	partCountForStatusCode[GPG_STATUS_PKA_TRUST_BAD] = 1;
	partCountForStatusCode[GPG_STATUS_PKA_TRUST_GOOD] = 1;
	partCountForStatusCode[GPG_STATUS_PLAINTEXT] = 3;
	partCountForStatusCode[GPG_STATUS_POLICY_URL] = 1;
	partCountForStatusCode[GPG_STATUS_REVKEYSIG] = 2;
	partCountForStatusCode[GPG_STATUS_USERID_HINT] = 2;
	

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
	if (_pinentryPath) {
		return [[_pinentryPath retain] autorelease];
	}

    //
    // Checking in order:
    // 1. pinentry-mac in a bundle named "org.gpgtools.Libmacgpg" 
    // 2. a defined "pinentry-program" in gpg-agent.conf
    // 3. a pinentry-mac executable in a set of dirs (e.g., /usr/local/bin) 
    //
    NSMutableArray *possibleBins = [NSMutableArray array];
    NSFileManager *fmgr = [NSFileManager defaultManager];

    // 1.
    NSString *bndlePath = [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] 
                           pathForResource:@"pinentry-mac" ofType:@"" 
                           inDirectory:@"pinentry-mac.app/Contents/MacOS"];
    if (bndlePath && [fmgr isExecutableFileAtPath:bndlePath]) 
        [possibleBins addObject:bndlePath];

    // 2.
    static NSString * const kPinentry_program = @"pinentry-program";
	GPGOptions *options = [GPGOptions sharedOptions];
    NSString *inconfPath = [options valueForKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
    inconfPath = [inconfPath stringByStandardizingPath];
    if (inconfPath && [fmgr isExecutableFileAtPath:inconfPath]) 
        [possibleBins addObject:inconfPath];
    else
        inconfPath = nil;

    // 3. Per mento: this feature is a rescue and update system 
    // if the user doesn't use MacGPG2
    if (!inconfPath) {
        if ([possibleBins count] < 1) {
            inconfPath = [self findExecutableWithName:@"../libexec/pinentry-mac.app/Contents/MacOS/pinentry-mac"];
            if (inconfPath)
                [possibleBins addObject:inconfPath];
        }

        if ([possibleBins count] > 0) {
            inconfPath = [possibleBins objectAtIndex:0];
            [options setValue:inconfPath forKey:kPinentry_program inDomain:GPGDomain_gpgAgentConf];
            [options gpgAgentFlush];
        }
    }

    NSString *foundPath = ([possibleBins count] > 0) ? [possibleBins objectAtIndex:0] : nil;
	if (foundPath) {
		_pinentryPath = [foundPath retain];
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
		if (!_gpgPath) {
			[self release];
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"GPG not found!") errorCode:GPGErrorNotFound];
		}
		self.gpgPath = _gpgPath;
		arguments = [[NSMutableArray alloc] initWithArray:args];
		batchMode = batch;
		errorCodes = [[NSMutableArray alloc] init];
		statusDict = [[NSMutableDictionary alloc] init];
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
	
    [outStream release];
	[errData release];
	[statusData release];
	[attributeData release];
	[outText release];
	[errText release];
	[statusText release];
	[inDatas release];
    //[cmdPipe release];
	[errorCodes release];
	[progressedLengths release];
	[statusDict release];
	
	self.lastUserIDHint = nil;
	self.lastNeedPassphrase = nil;
	
	self.gpgPath = nil;
	[writeException release];
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
	
    NSMutableArray *defaultArguments = [NSMutableArray arrayWithObjects:
                                        @"--no-greeting", @"--no-tty", @"--with-colons", @"--fixed-list-mode",
                                        @"--yes", @"--output", @"-", @"--status-fd", @"3", nil];
	
	
	if (progressInfo && [delegate respondsToSelector:@selector(gpgTask:progressed:total:)]) {
		for (GPGStream *gstream in inDatas) {
			inDataLength += [gstream length];
		}
		progressedLengths = [[NSMutableDictionary alloc] init];
		[defaultArguments addObject:@"--enable-progress-filter"];
    }

	
	
    // If batch mode is not set, add the command-fd using stdin.
    if (batchMode)
        [defaultArguments addObject:@"--batch"];
    else
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--no-batch", @"--command-fd", @"0", nil]];
	
    // If the attribute data is required, add the attribute-fd.
    if (getAttributeData)
        [defaultArguments addObjectsFromArray:[NSArray arrayWithObjects:@"--attribute-fd", @"4", nil]];
 
	// TODO: Optimize and make more generic.
    //Für Funktionen wie --decrypt oder --verify muss "--no-armor" nicht gesetzt sein.
    if ([arguments containsObject:@"--no-armor"] || [arguments containsObject:@"--no-armour"]) {
        NSSet *inputParameters = [NSSet setWithObjects:@"--decrypt", @"--verify", @"--import", @"--recv-keys", @"--refresh-keys", nil];
        for (NSString *argument in arguments) {
            if ([inputParameters containsObject:argument]) {
                NSUInteger index = [arguments indexOfObject:@"--no-armor"];
                if (index == NSNotFound) {
                    index = [arguments indexOfObject:@"--no-armour"];
                }
				if (index != NSNotFound) {
					[arguments replaceObjectAtIndex:index withObject:@"--armor"];
					while ((index = [arguments indexOfObject:@"--no-armor"]) != NSNotFound) {
						[arguments removeObjectAtIndex:index];
					}
					while ((index = [arguments indexOfObject:@"--no-armour"]) != NSNotFound) {
						[arguments removeObjectAtIndex:index];
					}
				}
                break;
            }
        }
    }
    [defaultArguments addObjectsFromArray:arguments];
	
	
    // Last but not least, add the fd's used to read the in-data from.
    int i = 5;
    for (id object in inDatas) {
        [defaultArguments addObject:[NSString stringWithFormat:@"/dev/fd/%d", i++]];
    }
		
    
	
    if ([delegate respondsToSelector:@selector(gpgTaskWillStart:)]) {
        [delegate gpgTaskWillStart:self];
    }
    
    // Allow the target to abort.
    if (cancelled)
		return GPGErrorCancelled;
    
    // Last before launching, create the inPipes and add the fd nums to the arguments.
    gpgTask = [[LPXTTask alloc] init];
    gpgTask.launchPath = self.gpgPath;
    gpgTask.standardInput = [[NSPipe pipe] noSIGPIPE];
    gpgTask.standardOutput = [[NSPipe pipe] noSIGPIPE];
    gpgTask.standardError = [[NSPipe pipe] noSIGPIPE];
    gpgTask.arguments = defaultArguments;
    
	GPGDebugLog(@"gpg %@", [gpgTask.arguments componentsJoinedByString:@" "]);
    
    // Now setup all the pipes required to communicate with gpg.
    [gpgTask inheritPipe:[[NSPipe pipe] noSIGPIPE] mode:O_RDONLY dup:3 name:@"status"];
    [gpgTask inheritPipe:[[NSPipe pipe] noSIGPIPE] mode:O_RDONLY dup:4 name:@"attribute"];
    NSMutableArray *pipeList = [[NSMutableArray alloc] init];
    NSMutableArray *dupList = [[NSMutableArray alloc] init];
    i = 5;
    for (id object in inDatas) {
        [pipeList addObject:[[NSPipe pipe] noSIGPIPE]];
        [dupList addObject:[NSNumber numberWithInt:i++]];
    }
    [gpgTask inheritPipes:pipeList mode:O_WRONLY dups:dupList name:@"ins"];
    [pipeList release];
    [dupList release];
    // Setup the task to be run in the parent process, before
    // the parent starts waiting for the child.
    NSMutableData *completeStatusData = [[NSMutableData alloc] initWithLength:0];
    
    
	__block NSException *blockException = nil;

    gpgTask.parentTask = ^{
        // Setup the dispatch queue.
        /*dispatch_queue_t*/ queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        // Create the group which will hold all the jobs which should finish before
        // the parent process starts waiting for the child.
       /* dispatch_group_t*/ collectorGroup = dispatch_group_create();
        // The data is written to the pipe as soon as gpg issues the status
        // BEGIN_ENCRYPTION or BEGIN_SIGNING. See processStatus.
        // When we want to encrypt or sign, the data can't be written before the 
		// BEGIN_ENCRYPTION or BEGIN_SIGNING status was issued, BUT
        // in every other case, gpg stalls till it received the data to decrypt.
        // So in that case, the data actually has to be written as the very first thing.
		
		NSArray *options = [NSArray arrayWithObjects:@"--encrypt", @"--sign", @"--clearsign", @"--detach-sign", @"--symmetric", @"-e", @"-s", @"-b", @"-c", nil];
		
        if([gpgTask.arguments firstObjectCommonWithArray:options] == nil) {
            dispatch_group_async(collectorGroup, queue, ^{
                [self _writeInputData];
            });
        }
        // Add each job to the collector group.
        dispatch_group_async(collectorGroup, queue, ^{
            if (!outStream)
                outStream = [[GPGMemoryStream memoryStream] retain];
            NSFileHandle *stdoutfh = [[gpgTask inheritedPipeWithName:@"stdout"] fileHandleForReading];

            NSAutoreleasePool *pool = nil;
            @try {
                NSData *data;
                pool = [[NSAutoreleasePool alloc] init];                
                while ((data = [stdoutfh readDataOfLength:kDataBufferSize]) && [data length] > 0) 
                {
                    [outStream writeData:data];
                    [pool release];
                    pool = [[NSAutoreleasePool alloc] init];
                }
            }
            @finally {
                [outStream flush];
                [pool release];
            }

            if ([GPGOptions debugLog]) 
                [self logDataContent:[self outData] message:@"[STDOUT]"];
        });
        dispatch_group_async(collectorGroup, queue, ^{
            self.errData = [[[gpgTask inheritedPipeWithName:@"stderr"] fileHandleForReading] readDataToEndOfFile];
			[self logDataContent:errData message:@"[STDERR]"];
        });
        if(getAttributeData) {
            dispatch_group_async(collectorGroup, queue, ^{
                self.attributeData = [[[gpgTask inheritedPipeWithName:@"attribute"] fileHandleForReading] readDataToEndOfFile];
            });
        }
				
        // Handle the status data. This is an important one.
        dispatch_group_async(collectorGroup, queue, ^{
			NSMutableString *line = [[NSMutableString alloc] init];
			@try {
				NSPipe *statusPipe = [gpgTask inheritedPipeWithName:@"status"];
				NSFileHandle *statusPipeReadingFH = [statusPipe fileHandleForReading];
				NSData *currentData;
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

			} @catch (NSException *exception) {
				blockException = [exception retain];
				[gpgTask cancel];
			} @finally {
				self.statusData = completeStatusData;
				[line release];
			}
        });
        
        // Wait for the jobs to finish.
        dispatch_group_wait(collectorGroup, DISPATCH_TIME_FOREVER);
        // And release the dispatch queue.
        dispatch_release(collectorGroup);
        
		[self logDataContent:statusData message:@"[STATUS]"];
    };
        
    // AAAAAAAAND NOW! Let's run the task and wait for it to complete.
    [gpgTask launchAndWait];
	
    
	if (blockException) 
		@throw [blockException autorelease];
	if (writeException)
		@throw writeException;
	
    exitcode = gpgTask.terminationStatus;
    
    if(cancelled)
        exitcode = GPGErrorCancelled;
    
    // Add some error handling here...
    // Close all open pipes by releasing the gpgTask.
    [gpgTask release];
	gpgTask = nil;
    
    if([delegate respondsToSelector:@selector(gpgTaskDidTerminate:)])
        [delegate gpgTaskDidTerminate:self];
    
    isRunning = NO;
    
    [completeStatusData release];
    return exitcode;
}

- (void)_writeInputData {
	if (inputDataWritten) return;
	inputDataWritten = YES;
    NSArray *pipeList = [gpgTask inheritedPipesWithName:@"ins"];
    for(int i = 0; i < [pipeList count]; i++) {
        NSFileHandle *ofh = [[pipeList objectAtIndex:i] fileHandleForWriting];
        NSAutoreleasePool *pool = nil;
        @try {
            GPGStream *input = [inDatas objectAtIndex:i];
            NSData *data;

            pool = [[NSAutoreleasePool alloc] init];            
            while ((data = [input readDataOfLength:kDataBufferSize]) && [data length] > 0) 
            {
                [ofh writeData:data];
                [pool release];
                pool = [[NSAutoreleasePool alloc] init];            
            }

            [ofh closeFile];
        }
        @catch (NSException *exception) {
            writeException = [exception retain];
            return;
        }
        @finally {
            [pool release];
        }
    }
}
- (void)processStatusLine:(NSString *)line {
    NSString *keyword, *value;
	
    line = [line stringByReplacingOccurrencesOfString:GPG_STATUS_PREFIX withString:@""];
	GPGDebugLog(@">> %@", line);
    
	NSMutableArray *parts = [[[line componentsSeparatedByString:@" "] mutableCopy] autorelease];
    keyword = [parts objectAtIndex:0];
	[parts removeObjectAtIndex:0];
    if ([parts count] > 0) {
        value = [parts componentsJoinedByString:@" "];
    } else {
        value = [NSString stringWithString:@""];
	}
    
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
			self.errorCode = GPGErrorCancelled;
            break;
        case GPG_STATUS_GET_HIDDEN:
            if([value isEqualToString:@"passphrase.enter"])
                isPassphraseRequest = YES;
            break;
        case GPG_STATUS_ERROR: {
            NSRange range = [value rangeOfString:@" "];
            if(range.length > 0)
                self.errorCode = [[value substringFromIndex:range.location + 1] intValue];
            break;
        }
		case GPG_STATUS_NO_SECKEY:
			self.errorCode = GPGErrorNoSecretKey;
			break;
		case GPG_STATUS_NO_PUBKEY:
			self.errorCode = GPGErrorNoPublicKey;
			break;
        case GPG_STATUS_BEGIN_ENCRYPTION:
        case GPG_STATUS_BEGIN_SIGNING:
            dispatch_group_async(collectorGroup, queue, ^{
                [self _writeInputData];
            });
            break;
		case GPG_STATUS_DECRYPTION_OKAY:
			[self unsetErrorCode:GPGErrorNoSecretKey];
			break;
		case GPG_STATUS_PROGRESS: {
			if (inDataLength) {
				NSString *what = [parts objectAtIndex:0];
				NSString *length = [parts objectAtIndex:2];
				
				if ([what hasPrefix:@"/dev/fd/"]) {
					progressedLength -= [[progressedLengths objectForKey:what] integerValue];
				}
				[progressedLengths setObject:length forKey:what];
				
				progressedLength += [length integerValue];
				
				[delegate gpgTask:self progressed:progressedLength total:inDataLength];
			}
			break;
		}
    }
	
	//Fill statusDict.
	NSUInteger partCount = [parts count];
	if (partCount > 0) {
		NSArray *myParts;
		NSUInteger maxCount = partCountForStatusCode[statusCode];
		if (maxCount > 0 && partCount > maxCount) { //We have more parts than maxCount (the real last part contain whitespaces).
			myParts = [parts subarrayWithRange:NSMakeRange(0, maxCount - 1)];
			NSString *lastPart = [[parts subarrayWithRange:NSMakeRange(maxCount, partCount - maxCount)] componentsJoinedByString:@" "];
			myParts = [myParts arrayByAddingObject:lastPart];
		} else {
			myParts = parts;
		}
		
		NSMutableArray *value = [statusDict objectForKey:keyword];
		if (value) {
			[value addObject:myParts];
		} else {
			[statusDict setObject:[NSMutableArray arrayWithObject:myParts] forKey:keyword];
		}
	} else {
		[statusDict setObject:[NSNumber numberWithBool:YES] forKey:keyword];
	}
	
	
	
	
	
    id returnValue = nil;
    if([delegate respondsToSelector:@selector(gpgTask:statusCode:prompt:)]) {
        returnValue = [delegate gpgTask:self statusCode:statusCode prompt:value];
    }
    
    // Get the passphrase from the pinetry if gpg asks for it.
    if(isPassphraseRequest) {
        if(!returnValue) {
            @try {
                returnValue = [self getPassphraseFromPinentry];
            }
            @catch(NSException *e) {
                // Cancel gpgTask, otherwise no new task can be run...
                [self cancel];
                @throw e;
            }
            if(returnValue)
                returnValue = [NSString stringWithFormat:@"%@\n", returnValue];
        }
        self.lastUserIDHint = nil;
        self.lastNeedPassphrase = nil;
    }
    
    // Write the return value to the command pipe.
    if(!cmdPipe) {
        @try {
            cmdPipe = [gpgTask inheritedPipeWithName:@"stdin"];
        }
        @catch (NSException *e) {
            cmdPipe = nil;
        }
    }
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

- (void)setErrorCode:(int)value {
	NSNumber *code = [NSNumber numberWithInt:value];
	if (![errorCodes containsObject:code]) {
		[errorCodes addObject:code];
		if (!errorCode) {
			errorCode = value;
		}
	}
}
- (void)unsetErrorCode:(int)value {
	NSNumber *code = [NSNumber numberWithInt:value];
	if ([errorCodes containsObject:code]) {
		[errorCodes removeObject:code];
		/* If other errors were found, set the errorCode to the
           first one, otherwise to No Error.
         */
        if([errorCodes count])
            errorCode = [[errorCodes objectAtIndex:0] intValue];
        else
            errorCode = GPGErrorNoError;
    }
}



/* Helper function to display NSData content. */
- (void)logDataContent:(NSData *)data message:(NSString *)message {
    NSString *tmpString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    GPGDebugLog(@"[DEBUG] %@: %@ >>", message, tmpString);
    [tmpString release];
}

- (void)cancel {
	cancelled = YES;
	if (gpgTask) {
		[gpgTask cancel];
	}
}

- (NSString *)getPassphraseFromPinentry {
	NSPipe *inPipe = [[NSPipe pipe] noSIGPIPE];
	NSPipe *outPipe = [[NSPipe pipe] noSIGPIPE];
	NSTask *pinentryTask = [[NSTask new] autorelease];
	
	NSString *pinentryPath = [[self class] pinentryPath];
	if ([pinentryPath length] == 0) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry not found!") errorCode:GPGErrorNoPINEntry];
	}
	
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
					   userID, [keyID shortKeyID]];
	} else {
		description = [NSString stringWithFormat:localizedLibmacgpgString(@"GetPassphraseDescription_Subkey"), 
					   userID, [keyID shortKeyID], [mainKeyID keyID]];
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
	
	NSData *inData = [inText UTF8Data];
	[[inPipe fileHandleForWriting] writeData:inData];
	
	
	
	
	[pinentryTask launch];
	NSData *output = [[outPipe fileHandleForReading] readDataToEndOfFile];
	[pinentryTask waitUntilExit];
	
	if (!output) {
		@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
	}
	NSString *outString = [output gpgString];
	
    // Versions prior to 0.8 of pinentry-mac do not seem
    // to support the OPTION cache-id yet, but still the
    // password is successfully retrieved.
    // To not abort on such an error, first the output string
    // is checked for a non empty D line and if not found,
    // any errors are processed.
    NSRange range = [outString rangeOfString:@"\nD "];
	if(range.location != NSNotFound) {
        range.location++;
        range.length--;
        range = [outString lineRangeForRange:range];
        range.location += 2;
        range.length -= 3;
        
        if(range.length > 0) {
            return [[outString substringWithRange:range] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    // Otherwise process the error.
    
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
			@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"Pinentry error!") errorCode:GPGErrorPINEntryError];
		}
		return nil;
	}
    return nil;
}

@end

//-----------------------------------------

@implementation NSPipe (SetNoSIGPIPE)

#ifndef F_SETNOSIGPIPE
#define F_SETNOSIGPIPE		73	/* No SIGPIPE generated on EPIPE */
#endif
#define FCNTL_SETNOSIGPIPE(fd) (fcntl(fd, F_SETNOSIGPIPE, 1))

- (NSPipe *)noSIGPIPE 
{
    FCNTL_SETNOSIGPIPE([[self fileHandleForReading] fileDescriptor]);
    FCNTL_SETNOSIGPIPE([[self fileHandleForWriting] fileDescriptor]);
    return self;
}

@end


