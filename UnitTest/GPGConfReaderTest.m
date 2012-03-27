/*
 GPGConfReaderTest.m
 Libmacgpg
 
 Copyright (c) 2012 Chris Fraire. All rights reserved.
 
 Libmacgpg is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <SenTestingKit/SenTestingKit.h>
#import "GPGConfReader.h"
#import "GPGStdSetting.h"
#import "GPGArraySetting.h"
#import "GPGDictSetting.h"

@interface GPGConfReaderTest : SenTestCase

@end

@implementation GPGConfReaderTest

- (void) testComponentsSeparatedOnWhitespace {

    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    
    NSString *input = @" a b  c ";
    NSString *trimmedInput = [input stringByTrimmingCharactersInSet:whsp];
    STAssertEqualObjects(@"a b  c", trimmedInput, @"Not trimmed as expected!");
    
    NSArray *splitTrimmed = [trimmedInput componentsSeparatedByCharactersInSet:whsp];
	STAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
}

- (void) testSplitString {

    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];

    NSString *input = @"a bb  ccc  ddddd";
    NSArray *splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
	STAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
    
    STAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    STAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    STAssertEqualObjects(@"ccc", [splitTrimmed objectAtIndex:2], @"Element not as expected!");
    STAssertEqualObjects(@"ddddd", [splitTrimmed objectAtIndex:3], @"Element not as expected!");

    input = @"a     bb  ";
    splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
 	STAssertTrue(3 == [splitTrimmed count], @"Not split as expected!");
   
    STAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    STAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    STAssertEqualObjects(@"", [splitTrimmed objectAtIndex:2], @"Element not as expected!");

    input = @" a    bb  ";
    splitTrimmed = [GPGConfReader splitString:input bySet:whsp maxCount:NSIntegerMax];
	STAssertTrue(4 == [splitTrimmed count], @"Not split as expected!");
    
    STAssertEqualObjects(@"", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    STAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
    STAssertEqualObjects(@"bb", [splitTrimmed objectAtIndex:2], @"Element not as expected!");
    STAssertEqualObjects(@"", [splitTrimmed objectAtIndex:3], @"Element not as expected!");
}

- (void) testLimitedSplitString {
    NSCharacterSet *whsp = [NSCharacterSet whitespaceCharacterSet];
    NSMutableCharacterSet *whspeqsign = [NSMutableCharacterSet characterSetWithCharactersInString:@"="];
    [whspeqsign formUnionWithCharacterSet:whsp];
    
    NSString *input = @"a   = bb ccc    ";
    NSArray *splitTrimmed = [GPGConfReader splitString:input bySet:whspeqsign maxCount:2];
	STAssertTrue(2 == [splitTrimmed count], @"Not split as expected!");
    
    STAssertEqualObjects(@"a", [splitTrimmed objectAtIndex:0], @"Element not as expected!");
    STAssertEqualObjects(@"bb ccc    ", [splitTrimmed objectAtIndex:1], @"Element not as expected!");
}

- (void) testKeyForLine {

    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    NSString *key = [reader condensedKeyForLine:@" option1 a=b"];
    STAssertEqualObjects(@"option1", key, @"Setting key not as expected!");

    key = [reader condensedKeyForLine:@" #option1 a=b"];
    STAssertNil(key, @"Unknown commented option not ignored!");

    key = [reader condensedKeyForLine:@" #no-sig-cache"];
    STAssertEqualObjects(@"sig-cache", key, @"\"no-\" not removed as expected!");

    key = [reader condensedKeyForLine:@" #no-auto-key-locate"];
    STAssertEqualObjects(@"no-auto-key-locate", key, @"Special case not handled as expected!");
}

- (void) testClassForLine {
    
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGStdSetting *setting = [reader buildForLine:@" #no-auto-key-locate  "];
    STAssertNotNil(setting, @"Unexpectedly nil!");
    STAssertEqualObjects(@"no-auto-key-locate", setting.key, @"Unexpected key!");
    STAssertTrue([setting isKindOfClass:[GPGStdSetting class]], @"Unexpected class!"); 

    setting = [reader buildForLine:@" keyserver-options k1=cert"];
    STAssertNotNil(setting, @"Unexpectedly nil!");
    STAssertEqualObjects(@"keyserver-options", setting.key, @"Unexpected key!");
    STAssertTrue([setting isKindOfClass:[GPGDictSetting class]], @"Unexpected class!"); 

    setting = [reader buildForLine:@" export-options   export-minimal"];
    STAssertNotNil(setting, @"Unexpectedly nil!");
    STAssertEqualObjects(@"export-options", setting.key, @"Unexpected key!");
    STAssertTrue([setting isKindOfClass:[GPGArraySetting class]], @"Unexpected class!"); 
}

@end
