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
#import "GPGTaskHelper.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"
#import "LPXTTask.h"
#import "GPGMemoryStream.h"
#import "GPGException.h"
#import "GPGGlobals.h"
//#import <sys/shm.h>
#import <fcntl.h>

static const NSUInteger kDataBufferSize = 65536; 


@interface GPGTask ()

@property (retain) NSData *errData;
@property (retain) NSData *statusData;
@property (retain) NSData *attributeData;
@property int errorCode;

+ (void)initializeStatusCodes;
- (void)unsetErrorCode:(int)value;

@end


@implementation GPGTask

NSDictionary *statusCodes;
char partCountForStatusCode[GPG_STATUS_COUNT];

@synthesize isRunning, batchMode, getAttributeData, delegate, userInfo, exitcode, errorCode, errData, statusData, attributeData, cancelled,
            progressInfo, statusDict, taskHelper = taskHelper;
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
    [errorCodes release];
	[statusDict release];
	
    if(taskHelper)
        [taskHelper release];
    taskHelper = nil;
    
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
    
    __block typeof(self) cself = self;
    taskHelper = [[GPGTaskHelper alloc] initWithArguments:defaultArguments];
    
    if(!outStream)
        outStream = [[GPGMemoryStream memoryStream] retain];
    
    taskHelper.output = self.outStream;
    taskHelper.inData = inDatas;
    taskHelper.processStatus = (lp_process_status_t)^(NSString *keyword, NSString *value){
        return [cself processStatusWithKeyword:keyword value:value];
    };
    taskHelper.progressHandler = ^(NSUInteger processedBytes, NSUInteger totalBytes) {
        [cself.delegate gpgTask:cself progressed:processedBytes total:totalBytes];
    };
    taskHelper.readAttributes = getAttributeData;
    taskHelper.checkForSandbox = YES;	
    
    @try {
        exitcode = [taskHelper run];
        self.statusData = taskHelper.status;
        self.attributeData = taskHelper.attributes;
        self.errData = taskHelper.errors;
    }
    @catch (NSException *exception) {
        @throw exception;
    }
    
    if([delegate respondsToSelector:@selector(gpgTaskDidTerminate:)])
        [delegate gpgTaskDidTerminate:self];
    
    isRunning = NO;
    
    return exitcode;
}

- (NSData *)processStatusWithKeyword:(NSString *)keyword value:(NSString *)value {
    
    NSArray *parts = [value isEqualToString:@""] ? [NSArray array] : [value componentsSeparatedByString:@" "];
    NSInteger statusCode = [[statusCodes objectForKey:keyword] integerValue];
    // No status code available, we're out of here.
    if(!statusCode)
        return nil;

    switch(statusCode) {
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
		case GPG_STATUS_DECRYPTION_OKAY:
			[self unsetErrorCode:GPGErrorNoSecretKey];
			break;
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
	
	// If the status is either GET_HIDDEN, GET_LINE or GET_BOOL
    // the GPG Controller is asked for a value to be passed
    // to GPG using the command pipe.
    id response = nil;
    if([delegate respondsToSelector:@selector(gpgTask:statusCode:prompt:)])
        response = [delegate gpgTask:self statusCode:statusCode prompt:value];
    
    return [response isKindOfClass:[NSData class]] ? response : [[response description] dataUsingEncoding:NSUTF8StringEncoding];
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

- (void)cancel {
    [taskHelper cancel];
}


/* Helper function to display NSData content. */
- (void)logDataContent:(NSData *)data message:(NSString *)message {
    NSString *tmpString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    GPGDebugLog(@"[DEBUG] %@: %@ >>", message, tmpString);
    [tmpString release];
}

@end


