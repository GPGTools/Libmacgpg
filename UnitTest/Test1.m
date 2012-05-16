#import "Test1.h"
#import <Libmacgpg/Libmacgpg.h>
#import "LPXTTask.h"
#include <sys/types.h>
#include <dirent.h>
#include "GPGStdSetting.h"

#define BDSKSpecialPipeServiceRunLoopMode @"BDSKSpecialPipeServiceRunLoopMode"

static NSString *skelconf = @"/usr/local/MacGPG2/share/gnupg/gpg-conf.skel";

@implementation Test1


- (void)setUp {
	gpgc = [[GPGController alloc] init];
	char tempPath[] = "/tmp/Libmacgpg_UnitTest-XXXXXX";
	tempDir = [NSString stringWithUTF8String:mkdtemp(tempPath)];
    NSLog(@"Tempdir is %@", tempDir);
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
	if (!([fileManager fileExistsAtPath:tempDir isDirectory:&isDirectory] && isDirectory)) {
		tempDir = nil;
		[NSException raise:@"Error" format:@"Can’t create temporary diretory."];
	}
	gpgc.gpgHome = tempDir;
}

- (void)tearDown {
//	if (tempDir) {
//		NSFileManager *fileManager = [NSFileManager defaultManager];
//		[fileManager removeItemAtPath:tempDir error:nil];
//	}
	[gpgc release];
}

- (void)testCase1 {
    STAssertNotNil(gpgc, @"Can’t init GPGController.");

    NSArray *array = [NSArray arrayWithObjects:[NSNumber numberWithInt:1],
                      [NSNumber numberWithInt:2], [NSNumber numberWithInt:3],
                      [NSNumber numberWithInt:4], [NSNumber numberWithInt:5], nil];
    NSLog(@"Found at position: %lu", (unsigned long)[array indexOfObject:[NSNumber numberWithInt:5]]);
    
    NSSet *keys = [gpgc allKeys];
    STAssertTrue(keys != nil && [keys count] == 0, @"Can’t list keys.");
    
    NSString *testKey_name = @"Test Key";
    NSString *testKey_email = @"nomail@example.com";
    NSString *testKey_comment = @"";
	
    [gpgc generateNewKeyWithName:testKey_name email:testKey_email comment:testKey_comment keyType:1 keyLength:1024 subkeyType:1 subkeyLength:1024 daysToExpire:5 preferences:nil passphrase:@""];
    keys = [gpgc allKeys];
    STAssertTrue([keys count] == 1, @"Can’t generate key.");
	
	GPGKey *key = [keys anyObject];
	STAssertTrue([key.name isEqualToString:testKey_name] && [key.email isEqualToString:testKey_email], @"Generate key faild.");
	
	NSString *keyID = key.keyID;
	
	NSData *input = [@"This is a test text." dataUsingEncoding:NSUTF8StringEncoding];
	NSData *output = [gpgc processData:input withEncryptSignMode:GPGEncryptSign recipients:[NSSet setWithObject:keyID] hiddenRecipients:nil];
	STAssertNotNil(output, @"processData faild.");
    STAssertTrue(![input isEqualToData:output], @"Signing did not produce different data!");

	NSData *decryptedData = [gpgc decryptData:output];
	STAssertNotNil(decryptedData, @"decryptData failed.");
    STAssertTrue([decryptedData isEqualToData:input], @"Round-trip sign/unsign failed!");
}

- (void)logDataContent:(NSData *)data message:(NSString *)message {
    NSString *tmpString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"[DEBUG] %@: %@ >>", message, tmpString);
    [tmpString release];
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    //NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSFileHandle *fh = [notification object];
    
    //if ([outputData length])
    //    stdoutData = [outputData retain];
    [self logDataContent:[fh availableData] message:@"GO FUCK THIS"];
    [fh waitForDataInBackgroundAndNotify];
}

- (void)testGPGConfGetContents {
    GPGConf *conf = [[GPGConf alloc] initWithPath:skelconf andDomain:GPGDomain_gpgConf];
    
    NSError *error = nil;
	NSString *skelContents = [NSString stringWithContentsOfFile:skelconf usedEncoding:nil error:&error];
    STAssertNotNil(skelContents, @"Unexpectedly nil!");
    NSString *reencoded = [conf getContents];
    STAssertEquals([skelContents length], [reencoded length], @"Content length mis-match!");
    STAssertEqualObjects(skelContents, reencoded, @"GPGConf did not round-trip contents!");
}

- (void)testGPGConfAlterContents {
	// Disabled because it doesn't work on the BuildBot.
	return;
    GPGConf *conf = [[GPGConf alloc] initWithPath:skelconf andDomain:GPGDomain_gpgConf];
    
    NSError *error = nil;
	NSString *skelContents = [NSString stringWithContentsOfFile:skelconf usedEncoding:nil error:&error];
    STAssertNotNil(skelContents, @"Unexpectedly nil!");
    
    [conf setValue:[NSNumber numberWithBool:TRUE] forKey:@"greeting"];
    NSString *reencoded = [conf getContents];
    NSString *gpath = [tempDir stringByAppendingPathComponent:@"gpg-testing.conf"];
	[reencoded writeToFile:gpath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    STAssertNil(error, @"writeToFile unexpectedly failed!");

    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/diff"];
    
    NSArray *arguments;
    arguments = [NSArray arrayWithObjects: skelconf, gpath, nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *diffout;
    diffout = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"diff returned:\n%@", diffout);
    NSString *expected = @"28c28\n< #no-greeting\n---\n> greeting\n";
    STAssertEqualObjects(expected, diffout, @"Diff not as expected!");
    
    [diffout release];
    [task release];
}

//- (void)stdoutNowAvailable:(NSNotification *)notification {
//    NSLog(@"Data coming in...");
//    NSLog(@"Notification: %@", notification);
////    NSFileHandle *fileHandle = (NSFileHandle*) [notification
////                                                object];
//    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
//    [self logDataContent:outputData message:@"Available Data"];
//    //[fileHandle waitForDataInBackgroundAndNotifyForModes:[NSArray arrayWithObject:BDSKSpecialPipeServiceRunLoopMode]];
//}

@end

/*
 STAssertNotNil(a1, description, ...)
 STAssertTrue(expression, description, ...)
 STAssertFalse(expression, description, ...)
 STAssertEqualObjects(a1, a2, description, ...)
 STAssertEquals(a1, a2, description, ...)
 STAssertThrows(expression, description, ...)
 STAssertNoThrow(expression, description, ...)
 STFail(description, ...)
*/ 
