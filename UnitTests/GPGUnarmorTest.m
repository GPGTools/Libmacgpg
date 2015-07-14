#import <XCTest/XCTest.h>
#import "GPGUnitTest.h"
#import "GPGUnArmor.h"


@interface GPGUnArmorTest : XCTestCase
@end

@implementation GPGUnArmorTest


- (void)testGPGUnArmor {
	// UnArmor every "Unarmor*.txt" file and compre it with "Unarmor*.res".
	
	NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *files = [fileManager contentsOfDirectoryAtPath:resourcePath error:nil];
	XCTAssertNotNil(files, @"Unable to find test files!");
	
	
	for (NSString *filename in files) {
		if (filename.length >= 11 && [[filename substringToIndex:7] isEqualToString:@"Unarmor"]) {
			if ([[filename substringWithRange:NSMakeRange(filename.length - 4, 4)] isEqualToString:@".txt"]) {
				NSString *filePath = [resourcePath stringByAppendingPathComponent:filename];
				NSString *resPath = [[filePath substringToIndex:filePath.length - 3] stringByAppendingString:@"res"];
				NSData *expectedData = [NSData dataWithContentsOfFile:resPath];
				
				GPGStream *stream = [GPGFileStream fileStreamForReadingAtPath:filePath];
				
				// The method to test
				NSData *unArmored = [[GPGUnArmor unArmor:stream] readAllData];

				
				if (unArmored.length == 0 || ![unArmored isEqualToData:expectedData]) {
					XCTFail(@"Test %@ failed!", filename);
					continue;
				}
				
				printf("%s\n", [[NSString stringWithFormat:@"Test %@ passed.", filename] UTF8String]);
			}
		}
	}
}


@end
