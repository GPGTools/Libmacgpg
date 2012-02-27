/*
 GPGDictSettingTest.m
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
#import "GPGDictSetting.h"
#import "GPGConfReader.h"

@interface GPGDictSettingTest : SenTestCase {
    NSString *key;
    NSDictionary *testdict;
}

@end

@implementation GPGDictSettingTest

- (void) setUp {
    key = @"keyserver-options";
    testdict = [[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:@"abc", @"def", nil], 
                @"keyserver1", nil] retain];
}

- (void) tearDown {
    [testdict release];
}

- (void) testSetValue {
    GPGDictSetting *setting = [[GPGDictSetting alloc] initForKey:key];
    [setting setValue:testdict];

    id value = [setting value];
    STAssertNotNil(value, @"Unexpectedly nil!");
    STAssertTrue([value count] == [testdict count], @"Incorrect count!");
    [setting release];
}

- (void) testSetNil {
    GPGDictSetting *setting = [[GPGDictSetting alloc] initForKey:key];
    [setting setValue:testdict];
    [setting setValue:nil];
    
    id value = [setting value];
    STAssertNotNil(value, @"Unexpectedly nil!");
    STAssertTrue([value count] == 0, @"Incorrect count!");
    [setting release];
}

- (void) testGetValue {
    
    GPGDictSetting *setting = [[GPGDictSetting alloc] initForKey:key];
    [setting setValue:testdict];
    NSString* desc = [setting description];
    STAssertEqualObjects(@"keyserver-options keyserver1=abc def\n", desc, @"description not as expected!");

    [setting release];
}

- (void) testAppendLine {
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGDictSetting *setting = [[GPGDictSetting alloc] initForKey:key];
    [setting appendLine:@"keyserver-options  keyserver1=a, b" withReader:reader];
    [setting appendLine:@"keyserver-options  keyserver1=c, d" withReader:reader];
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    STAssertEqualObjects(@"#keyserver-options keyserver1=c d\n", desc, @"description not as expected!");
    
    [setting release];
}

@end
