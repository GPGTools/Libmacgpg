#import "Test1.h"
#import <Libmacgpg/Libmacgpg.h>

@implementation Test1


- (void)setUp {
	gpgc = [[GPGController alloc] init];
	char tempPath[] = "/tmp/Libmacgpg_UnitTest-XXXXXX";
	tempDir = [NSString stringWithUTF8String:mkdtemp(tempPath)];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
	if (!([fileManager fileExistsAtPath:tempDir isDirectory:&isDirectory] && isDirectory)) {
		tempDir = nil;
		[NSException raise:@"Error" format:@"Can’t create temporary diretory."];
	}
	gpgc.gpgHome = tempDir;
}

- (void)tearDown {
	if (tempDir) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		[fileManager removeItemAtPath:tempDir error:nil];
	}
	[gpgc release];
}

- (void)testCase1 {
	STAssertNotNil(gpgc, @"Can’t init GPGController.");
	
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
	
	//TODO: Add more tests.
	
	
}

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
