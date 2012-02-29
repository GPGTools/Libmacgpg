/*
 GPGArraySettingTest.m
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
#import "GPGArraySetting.h"
#import "GPGConfReader.h"

@interface GPGArraySettingTest : SenTestCase {
    NSString *key;
    NSArray *testwords;
}

@end

@implementation GPGArraySettingTest

- (void) setUp {
    key = @"auto-key-locate";
    testwords = [[NSArray arrayWithObjects:@"cert", @"pka", nil] retain];
}

- (void) tearDown {
    [testwords release];
    testwords = nil;
}

- (void) testSetValue {
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];

    id value = [setting value];
    STAssertNotNil(value, @"Unexpectedly nil!");
    STAssertTrue([value count] == [testwords count], @"Incorrect count!");
    [setting release];
}

- (void) testSetNil {
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];
    [setting setValue:nil];
    
    id value = [setting value];
    STAssertNotNil(value, @"Unexpectedly nil!");
    STAssertTrue([value count] == 0, @"Incorrect count!");
    [setting release];
}

- (void) testGetValue {    
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting setValue:testwords];
    NSString* desc = [setting description];
    STAssertEqualObjects(@"auto-key-locate cert pka\n", desc, @"description not as expected!");
    
    [setting release];
}

- (void) testAppendLine {
    GPGConfReader *reader = [GPGConfReader readerForDomain:GPGDomain_gpgConf];
    GPGArraySetting *setting = [[GPGArraySetting alloc] initForKey:key];
    [setting appendLine:@"auto-key-locate  cert,pka" withReader:reader];
    setting.isActive = FALSE;
    NSString* desc = [setting description];
    STAssertEqualObjects(@"#auto-key-locate cert pka\n", desc, @"description not as expected!");
    
    [setting release];
}

@end
