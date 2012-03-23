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
#import "GPGSignature.h"

@interface GPGTestVerify : SenTestCase

@end

@implementation GPGTestVerify

- (void)testVerifyDataLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringLF" ofType:@"txt"];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not verify as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.hasFilled, @"Did not verify as expected!");
}

- (void)testVerifyDataCRLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCRLF" ofType:@"txt"];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not verify as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.hasFilled, @"Did not verify as expected!");
}

- (void)testVerifyDataCR {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCR" ofType:@"txt"];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not verify as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.hasFilled, @"Did not verify as expected!");
}

- (void)testVerifyForceLF_to_CRLF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringLF" ofType:@"txt"];
    NSString *dstring = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
    data = [dstring UTF8Data];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not verify as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.hasFilled, @"Did not verify as expected!");
}

- (void)testVerifyForceCRLF_to_LF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCRLF" ofType:@"txt"];
    NSString *dstring = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    data = [dstring UTF8Data];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not verify as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorNoError, @"Did not verify as expected!");
    STAssertTrue(signature.hasFilled, @"Did not verify as expected!");
}

- (void)testBadVerifyForceCR_to_LF {
    NSData *data = [GPGResourceUtil dataForResourceAtPath:@"SignedInputStringCR" ofType:@"txt"];
    NSString *dstring = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    dstring = [dstring stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    data = [dstring UTF8Data];
    GPGController* ctx = [GPGController gpgController];
    ctx.useArmor = YES;
    NSArray* sigs = [ctx verifySignature:data originalData:nil];
    STAssertEquals([sigs count], 1ul, @"Did not get entry as expected!");
    GPGSignature *signature = ([sigs count]) ? [sigs objectAtIndex:0] : nil;
    STAssertEquals(signature.status, GPGErrorBadSignature, @"Verified unexpectedly!");
    STAssertTrue(signature.hasFilled, @"Did not get entry as expected!");
}

@end
