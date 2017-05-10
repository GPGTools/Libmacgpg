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


@end
