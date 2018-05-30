//
//  GPGControllerTest.m
//  Libmacgpg
//
//  Created by Mento on 24.04.17.
//
//

#import <XCTest/XCTest.h>
#import "GPGUnitTest.h"
#import "GPGController.h"


@interface GPGControllerTest : XCTestCase
@end

@implementation GPGControllerTest

+ (void)setUp {
	[GPGUnitTest setUpTestDirectory];
}

- (void)testDecryptData {
	NSData *encrypted = [GPGUnitTest dataForResource:@"Encrypted.gpg"];
	NSData *decrypted = [gpgc decryptData:encrypted];
	XCTAssertEqualObjects(decrypted, [NSData dataWithBytes:"OK\n" length:3], @"Did not decrypt as expected!");
}

- (void)testDecryptCases {
	// Decrypt every "*.gpg" file in the Decrypt folder and compares it with the corresponding ".res".
	
	NSString *resourcePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Decrypt"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *files = [fileManager contentsOfDirectoryAtPath:resourcePath error:nil];
	XCTAssertNotNil(files, @"Unable to find test files!");
	
	
	for (NSString *filename in files) {
		if ([filename.pathExtension isEqualToString:@"gpg"]) {
			NSString *filePath = [resourcePath stringByAppendingPathComponent:filename];
			NSString *resPath = [filePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"res"];
			NSData *expectedData = [NSData dataWithContentsOfFile:resPath];
			
			GPGStream *encrypted = [GPGFileStream fileStreamForReadingAtPath:filePath];
			GPGMemoryStream *decrypted = [GPGMemoryStream memoryStream];
			
			[gpgc decryptTo:decrypted data:encrypted];
			
			NSData *decryptedData = decrypted.readAllData;
			
			if ([decryptedData isEqualToData:expectedData]) {
				printf("%s\n", [[NSString stringWithFormat:@"Test Decrypt %@ passed.", filename] UTF8String]);
			} else {
				XCTFail(@"Test Decrypt %@ failed!", filename);
			}
		}
	}
}
	

@end
