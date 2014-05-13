//
//  GPGTestVerify.h
//  Libmacgpg
//
//  Created by Chris Fraire on 3/22/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//
#import <SenTestingKit/SenTestingKit.h>
#import "GPGController.h"
#import "GPGResourceUtil.h"
#import "GPGKeyManager.h"
#import "GPGSignature.h"

@interface GPGTestVerify : SenTestCase {
    BOOL _didImport;
}

@end

@implementation GPGTestVerify

- (void)setUp {
    if (!_didImport) {
        NSData *data = [GPGResourceUtil dataForResourceAtPath:@"OpenPGP" ofType:@"asc"];
        GPGController *ctx = [GPGController gpgController];
        [ctx importFromData:data fullImport:TRUE];
        _didImport = TRUE;
    }
}

- (BOOL)isOneValidSig:(NSArray *)sigs {
	STAssertTrue(sigs.count == 1, @"Did not verify as expected!");
    GPGSignature *signature = sigs.count ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.fingerprint, @"Did not verify as expected!");
}



- (void)testAAAFindTestKey {
	STAssertNotNil([[[GPGKeyManager sharedInstance] keysByKeyID] objectForKey:@"F988A4590DB03A7D"], @"Test key not imported!");
}

- (void)testVerifyDataLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringLF" ofType:@"txt"];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	[self isOneValidSig:sigs];
}

- (void)testVerifyDataCRLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCRLF" ofType:@"txt"];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	[self isOneValidSig:sigs];
}

- (void)testVerifyDataCR {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCR" ofType:@"txt"];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	[self isOneValidSig:sigs];
}

- (void)testVerifyForceLF_to_CRLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringLF" ofType:@"txt"];
    NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
    data = [dstring UTF8Data];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	[self isOneValidSig:sigs];
}

- (void)testVerifyForceCRLF_to_LF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCRLF" ofType:@"txt"];
    NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    data = [dstring UTF8Data];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	[self isOneValidSig:sigs];
}

- (void)testBadVerifyForceCR_to_LF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCR" ofType:@"txt"];
    NSString *dstring = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    data = [dstring UTF8Data];
    GPGController *ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray *sigs = [ctx verifySignature:data originalData:nil];
	STAssertTrue(sigs.count == 1, @"Did not verify as expected!");
    GPGSignature *signature = sigs.count ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorBadSignature, @"Verified unexpectedly!");
    STAssertTrue(signature.fingerprint, @"Did not verify as expected!");
}

@end
