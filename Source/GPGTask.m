
#import "GPGTask.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"


@interface GPGTask (Private)

+ (void)initializeStatusCodes;
- (void)readDataFromFD:(NSDictionary *)dictionary;
- (int)processStatusData:(char *)data;
- (void)writeDataToFD:(NSDictionary *)dict;
- (NSString *)getPassphraseFromPinentry;

@end


@implementation GPGTask

NSString *_gpgPath;
NSDictionary *statusCodes;

@synthesize isRunning, batchMode, getAttributeData, delegate, userInfo, exitcode, errorCode, gpgPath, outData, errData, statusData, attributeData, lastUserIDHint, lastNeedPassphrase, canceled;

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
			@throw [NSException exceptionWithName:GPGTaskException reason:localizedString(@"GPG not found!") userInfo:nil];
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
				   [NSNumber numberWithInteger:GPG_STATUS_ERROR], @"ERROR",
				   [NSNumber numberWithInteger:GPG_STATUS_ERRSIG], @"ERRSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_EXPKEYSIG], @"EXPKEYSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_EXPSIG], @"EXPSIG",
				   [NSNumber numberWithInteger:GPG_STATUS_FILE_DONE], @"FILE_DONE",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_BOOL], @"GET_BOOL",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_HIDDEN], @"GET_HIDDEN",
				   [NSNumber numberWithInteger:GPG_STATUS_GET_LINE], @"GET_LINE",
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
	[inFileDescriptors release];
	
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
	int outPipe[2];
	int errPipe[2];
	int statusPipe[2];
	int attributePipe[2];
	int cmdPipe[2];
	
	isRunning = YES;
	
	//Create pipes (attributePipe only if getAttributeData is set)
	if (pipe(outPipe) || pipe(errPipe) || pipe(statusPipe) || pipe(cmdPipe) || (getAttributeData && pipe(attributePipe))) {
		isRunning = NO;
		@throw [NSException exceptionWithName:GPGTaskException
									   reason:@"The pipe can't be created!"
									 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"errno"]];
	}
	cmdFileDescriptor = cmdPipe[1];
	
	
	NSUInteger i, inDatasCount = [inDatas count];
	int inPipes[inDatasCount + 1][2];
	inFileDescriptors = [[NSMutableArray alloc] initWithCapacity:inDatasCount];
	
	for (i = 0; i < inDatasCount; i++) {
		if (pipe(inPipes[i])) {
			isRunning = NO;
			@throw [NSException exceptionWithName:GPGTaskException
										   reason:@"The pipe can't be created!"
										 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"errno"]];			
		}
		[inFileDescriptors addObject:[NSNumber numberWithInt:inPipes[i][1]]];
	}
		
	if ([delegate respondsToSelector:@selector(gpgTaskWillStart:)]) {
		[delegate gpgTaskWillStart:self];
	}
	
	if (canceled) {
		return GPGErrorCancelled;
	}
	
	//fork
	pid_t pid = fork();
	if (pid == 0) { //Child process
		//Close unused pipes.
		if (close(outPipe[0]) || close(errPipe[0]) || close(statusPipe[0]) || close(cmdPipe[1]) || (getAttributeData && close(attributePipe[0]))) {
			exit(101);			
		}
		
		//Use pipes for in- and output.
		if (dup2(outPipe[1], 1) == -1 || dup2(errPipe[1], 2) == -1 || dup2(statusPipe[1], 3) == -1 || dup2(cmdPipe[0], 0) == -1 || (getAttributeData && dup2(attributePipe[1], 4) == -1)) {
			exit(102);
		}
		
		
		//Callculate number of arguments.
		int numArgs = 15, argPos = 1;
		if (getAttributeData) {
			numArgs += 2; //"--attribute-fd" and "4".
		}
		numArgs += inDatasCount;
		
		numArgs += [arguments count];
		
		
		//Create array with arguments.
		char* argv[numArgs];
		argv[0] = (char *)[gpgPath fileSystemRepresentation];

		
		argv[argPos++] = "--no-greeting";
		argv[argPos++] = "--no-tty";
		argv[argPos++] = "--with-colons";
		argv[argPos++] = "--yes";
		argv[argPos++] = "--command-fd";
		argv[argPos++] = "0";
		argv[argPos++] = "--status-fd";
		argv[argPos++] = "3";
		argv[argPos++] = "--output";
		argv[argPos++] = "-";
		argv[argPos++] = batchMode ? "--batch" : "--no-batch";
		argv[argPos++] = "--fixed-list-mode"; //For GPG1
		//argv[argPos++] = "--use-agent"; //For GPG1
		
		
		if (getAttributeData) {
			argv[argPos++] = "--attribute-fd";
			argv[argPos++] = "4";
		}
		
		
		//Für Funktionen wie --decrypt oder --verify sollte "--no-armor" nicht gesetzt sein.
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
		
		
		for (NSString *argument in arguments) {
			argv[argPos++] = (char*)[argument cStringUsingEncoding:NSUTF8StringEncoding];
		}
		
		for (i = 0; i < inDatasCount; i++) {
			if (close(inPipes[i][1])) {
				exit(103);			
			}
			if (dup2(inPipes[i][0], i + 5) == -1) {
				exit(104);
			}
			char *arg;
			asprintf(&arg, "/dev/fd/%i", i + 5);
			argv[argPos++] = arg;			
		}
		
		argv[argPos] = nil;

		
		execv(argv[0], argv); //Run GPG.
		
		exit(111);
	} else if (pid < 0) { //fork Error
		isRunning = NO;
		@throw [NSException exceptionWithName:GPGTaskException
									   reason:@"fork failed!"
									 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"errno"]];
	} else { //Parent process
		childPID = pid;
		@try {
			//Close unused pipes.
			if (close(outPipe[1]) || close(errPipe[1]) || close(statusPipe[1]) || close(cmdPipe[0]) || (getAttributeData && close(attributePipe[1]))) {
				@throw [NSException exceptionWithName:GPGTaskException
											   reason:@"The pipe can't be closed!"
											 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"errno"]];
			}
			
			for (i = 0; i < inDatasCount; i++) {
				if (close(inPipes[i][0])) {
					@throw [NSException exceptionWithName:GPGTaskException
												   reason:@"The pipe can't be closed!"
												 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"errno"]];
				}
				[NSThread detachNewThreadSelector:@selector(writeDataToFD:) toTarget:self withObject:
				 [NSDictionary dictionaryWithObjectsAndKeys:[inDatas objectAtIndex:i], @"data", [inFileDescriptors objectAtIndex:i], @"fd", nil]];				
			}
			
			
			NSThread *t1 = [[[NSThread alloc] initWithTarget:self selector:@selector(readDataFromFD:) object:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:outPipe[0]], @"fd", [NSValue valueWithPointer:&outData], @"data", [NSNumber numberWithInt:32000], @"bufferSize", nil]] autorelease];
			NSThread *t2 = [[[NSThread alloc] initWithTarget:self selector:@selector(readDataFromFD:) object:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:errPipe[0]], @"fd", [NSValue valueWithPointer:&errData], @"data", nil]] autorelease];
			NSThread *t3 = [[[NSThread alloc] initWithTarget:self selector:@selector(readDataFromFD:) object:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:statusPipe[0]], @"fd", [NSValue valueWithPointer:&statusData], @"data", [NSNumber numberWithBool:YES], @"isStatusFD", nil]] autorelease];
			NSThread *t4 = nil;
			[t1 start];
			[t2 start];
			[t3 start];
			if (getAttributeData) {
				t4 = [[[NSThread alloc] initWithTarget:self selector:@selector(readDataFromFD:) object:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:attributePipe[0]], @"fd", [NSValue valueWithPointer:&attributeData], @"data", [NSNumber numberWithInt:32000], @"bufferSize", nil]] autorelease];
				[t4 start];
			}
			
			int retval, stat_loc;
			while ((retval = waitpid(pid, &stat_loc, 0)) != pid) {
				int e = errno;
				if (retval != -1 || e != EINTR) {
					NSLog(@"waitpid loop: %i errno: %i, %s", retval, e, strerror(e));
				}
			}
			exitcode = WEXITSTATUS(stat_loc);
			
			while ([t1 isExecuting] || [t2 isExecuting] || [t3 isExecuting] || [t4 isExecuting]) {
				//TODO: Optimize sleep!
				usleep(10000);
			}
			if (canceled || (exitcode != 0 && passphraseStatus == 3)) {
				exitcode = GPGErrorCancelled;
			}
		} @catch (NSException * e) {
			kill(pid, SIGTERM);
			@throw;
		} @finally {
			close(outPipe[0]);
			close(errPipe[0]);
			close(statusPipe[0]);
			if (cmdFileDescriptor != -1) {
				close(cmdFileDescriptor);
			}
			if (getAttributeData) {
				close(attributePipe[0]);
			}

			if ([delegate respondsToSelector:@selector(gpgTaskDidTerminated::)]) {
				[delegate gpgTaskDidTerminated:self];
			}
			childPID = 0;
			
			isRunning = NO;
		}
	}
	
	return exitcode;
}

- (void)cancel {
	canceled = YES;
	if (childPID) {
		kill(childPID, SIGTERM);
	}
}


- (void)readDataFromFD:(NSDictionary *)dictionary {
	int fd = [[dictionary objectForKey:@"fd"] intValue];
	NSData **data = [[dictionary objectForKey:@"data"] pointerValue];
	BOOL isStatusFD = [[dictionary objectForKey:@"isStatusFD"] boolValue];
	int bufferSize = [[dictionary objectForKey:@"bufferSize"] intValue];
	bufferSize = bufferSize ? bufferSize : 2000;
	int dataRead, readPos = 0, processPos = 0;
	char *buffer = malloc(bufferSize + 1);
	
	if (!buffer) {
		@throw [NSException exceptionWithName:GPGTaskException 
									   reason:@"malloc failed!" 
									 userInfo:nil];
	}
	
	
	while ((dataRead = read(fd, buffer + readPos, bufferSize - readPos)) > 0) {
		readPos += dataRead;
		if (isStatusFD) {
			buffer[readPos] = 0;
			processPos += [self processStatusData:buffer + processPos];
		}
		if (readPos >= bufferSize) {
			bufferSize *= 4;
			buffer = realloc(buffer, bufferSize + 1);
			if (!buffer) {
				@throw [NSException exceptionWithName:GPGTaskException 
											   reason:@"realloc failed!" 
											 userInfo:nil];
			}
		}
	}
	if (dataRead > 0) {
		readPos += dataRead;
		if (isStatusFD) {
			buffer[readPos] = 0;
			[self processStatusData:buffer + processPos];
		}
	}
	*data = [[NSData alloc] initWithBytes:buffer length:readPos];
	
	free(buffer);
}

- (int)processStatusData:(char *)data {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int bytesProcessed = 0;
	char *lineStart, *lineEnd, *searchPos;
	searchPos = data;
	
	while ((lineStart = strstr(searchPos, "[GNUPG:] ")) && (lineEnd = strchr(lineStart, '\n'))) {
		lineEnd[0] = 0;
		lineStart += 9;
		

		NSString *line = [NSString stringWithUTF8String:lineStart];
		if (line == nil) {
			line = [NSString stringWithCString:lineStart encoding:NSASCIIStringEncoding];
		}
		lineEnd[0] = '\n';
		bytesProcessed = lineEnd - data + 1;
		searchPos = lineEnd + 1;
		
		NSRange range = [line rangeOfString:@" "];
		NSString *keyword, *prompt = nil;
		
		if (range.length > 0) {
			keyword = [line substringToIndex:range.location];
			prompt = [line substringFromIndex:range.location + 1];
		} else {
			keyword = line;
		}

		
		
		NSInteger statusCode = [[statusCodes objectForKey:keyword] integerValue];
		if (statusCode) {
			BOOL isPassphraseRequest = NO;
			switch (statusCode) {
				case GPG_STATUS_USERID_HINT: {
					range = [prompt rangeOfString:@" "];
					NSString *keyID = [prompt substringToIndex:range.location];
					NSString *userID = [prompt substringFromIndex:range.location + 1];
					self.lastUserIDHint = [NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", userID, @"userID", nil];
					passphraseStatus = 1;
					break; }
				case GPG_STATUS_NEED_PASSPHRASE: {
					NSArray *components = [prompt componentsSeparatedByString:@" "];
					self.lastNeedPassphrase = [NSDictionary dictionaryWithObjectsAndKeys:
										  [components objectAtIndex:0], @"mainKeyID", 
										  [components objectAtIndex:1], @"keyID", 
										  [components objectAtIndex:2], @"keyType", 
										  [components objectAtIndex:3], @"keyLength", nil];
					passphraseStatus = 1;
					break; }
				case GPG_STATUS_BAD_PASSPHRASE:
					self.lastUserIDHint = nil;
					self.lastNeedPassphrase = nil;
					passphraseStatus = 2;
					break;
				case GPG_STATUS_MISSING_PASSPHRASE:
					self.lastUserIDHint = nil;
					self.lastNeedPassphrase = nil;
					passphraseStatus = 3;
					break;
				case GPG_STATUS_GET_HIDDEN:
					if ([prompt isEqualToString:@"passphrase.enter"]) {
						isPassphraseRequest = YES;
					}
					break;
				case GPG_STATUS_ERROR:
					range = [prompt rangeOfString:@" "];
					if (range.length > 0) {
						errorCode = [[prompt substringFromIndex:range.location + 1] intValue];
					}
					break;

			}
			id returnValue = nil;
			if ([delegate respondsToSelector:@selector(gpgTask:statusCode:prompt:)]) {
				returnValue = [delegate gpgTask:self statusCode:statusCode prompt:prompt];
			}
			
			
			if (isPassphraseRequest) {
				if (!returnValue) {
					returnValue = [self getPassphraseFromPinentry];
					if (returnValue) {
						returnValue = [NSString stringWithFormat:@"%@\n", returnValue];
					}
				}
				self.lastUserIDHint = nil;
				self.lastNeedPassphrase = nil;
			}
			
			
			
			if (cmdFileDescriptor != -1) {
				if (returnValue) {
					NSData *dataToWrite = nil;
					if ([returnValue isKindOfClass:[NSData class]]) {
						dataToWrite = returnValue;
					} else {
						dataToWrite = [[returnValue description] dataUsingEncoding:NSUTF8StringEncoding];
					}
					write(cmdFileDescriptor, [dataToWrite bytes], [dataToWrite length]);				
				} else if (statusCode == GPG_STATUS_GET_BOOL || statusCode == GPG_STATUS_GET_HIDDEN || statusCode == GPG_STATUS_GET_LINE) {
					close(cmdFileDescriptor);
					cmdFileDescriptor = -1;
				}
			}
		} else {
			NSLog(@"Unknown Status code: \"%@\"!", keyword);
		}
	}
		
	[pool drain];
	return bytesProcessed;
}


- (NSString *)getPassphraseFromPinentry {
	NSPipe *inPipe = [NSPipe pipe];
	NSPipe *outPipe = [NSPipe pipe];
	NSTask *pinentryTask = [[NSTask new] autorelease];
	
	pinentryTask.launchPath = [[self class] pinentryPath];
	
	pinentryTask.standardInput = inPipe;
	pinentryTask.standardOutput = outPipe;

	
	
		
	NSString *keyID = [lastNeedPassphrase objectForKey:@"keyID"];
	NSString *mainKeyID = [lastNeedPassphrase objectForKey:@"mainKeyID"];
	NSString *userID = [lastUserIDHint objectForKey:@"userID"];
	//NSString *keyLength = [lastNeedPassphrase objectForKey:@"keyLength"];
	//NSString *keyType = [lastNeedPassphrase objectForKey:@"keyType"];
	
	NSString *description;
	if ([keyID isEqualToString:mainKeyID]) {
		description = [NSString stringWithFormat:localizedString(@"GetPassphraseDescription"), 
					   userID, getShortKeyID(keyID)];
	} else {
		description = [NSString stringWithFormat:localizedString(@"GetPassphraseDescription_Subkey"), 
					   userID, getShortKeyID(keyID), getShortKeyID(mainKeyID)];
	}
	description = [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *prompt = [localizedString(@"PassphraseLabel") stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
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



- (void)writeDataToFD:(NSDictionary *)dict {
	NSData *data = [dict objectForKey:@"data"];
	int fd = [[dict objectForKey:@"fd"] intValue];
	write(fd, [data bytes], [data length]);
	close(fd);
}


@end



