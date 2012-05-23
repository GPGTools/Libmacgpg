//
//  GPGSignatureTest.m
//  Libmacgpg
//
//  Created by Chris Fraire on 5/16/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "GPGSignature.h"
#import "GPGGlobals.h"

@interface GPGSignatureTest : SenTestCase

@end

@implementation GPGSignatureTest

- (void)testGoodSignatureDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_GOODSIG andPrompt:@"ABCZYX someone@someplace.com"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Signed (someone@someplace.com)", @"Unreadable!");
    [sig release];
}

- (void)testExpiredSignatureDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_EXPSIG andPrompt:@"ABCZYX someone@someplace.com"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Signature expired (someone@someplace.com)", @"Unreadable!");
    [sig release];
}

- (void)testExpiredKeyDesc {
    // same as expired signature
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_EXPKEYSIG andPrompt:@"ABCZYX someone@someplace.com"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Signature expired (someone@someplace.com)", @"Unreadable!");
    [sig release];
}

- (void)testBadKeyDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_BADSIG andPrompt:@"ABCZYX someone@someplace.com"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Bad signature (someone@someplace.com)", @"Unreadable!");
    [sig release];
}

- (void)testNoPublicKeyDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_ERRSIG andPrompt:@"ABCZYX 1 hash class date 9"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Signed by stranger (ABCZYX GPG_RSAAlgorithm)", @"Unreadable!");
    [sig release];
}

- (void)testUnknownAlgorithmDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_ERRSIG andPrompt:@"ABCZYX 244 hash class date 4"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Unverifiable signature (ABCZYX Algorithm_244)", @"Unreadable!");
    [sig release];
}

- (void)testGeneralErrorDesc {
    GPGSignature *sig = [[GPGSignature alloc] init];
    [sig addInfoFromStatusCode:GPG_STATUS_BADSIG andPrompt:@"ABCZYX someone@someplace.com"];
    [sig addInfoFromStatusCode:GPG_STATUS_ERRSIG andPrompt:@"ABCZYX alg hash class date 999"];
    NSString *desc = [sig humanReadableDescriptionShouldLocalize:NO];
    STAssertEqualObjects(desc, @"Signature error (someone@someplace.com)", @"Unreadable!");
    [sig release];
}

@end
