/* GPGLiteralDataPacket.m
 Copyright © Roman Zechmeister, 2015
 
 This file is part of Libmacgpg.
 
 Libmacgpg is free software; you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 Libmacgpg is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA
 */

#import "GPGLiteralDataPacket.h"
#import "GPGPacket_Private.h"

@interface GPGLiteralDataPacket ()
@property (nonatomic, readwrite) NSInteger format;
@property (nonatomic, strong, readwrite) NSString *filename;
@property (nonatomic, strong, readwrite) NSDate *date;
@property (nonatomic, copy, readwrite) NSData *content;
@end


@implementation GPGLiteralDataPacket
@synthesize format, filename, date, content;


- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.format = parser.byte;
	
	NSUInteger len = parser.byte;
	
	self.filename = [parser stringWithLength:len];
	
	self.date = parser.date;
	length = length - 6 - len;
	
	
	NSMutableData *tempData = [NSMutableData data];
	NSUInteger i = 0;
	
	while (length > 0) {
		tempData.length += length;
		UInt8 *bytes = tempData.mutableBytes;
		
		for (NSUInteger j = 0; j < length; j++) {
			bytes[i++] = (UInt8)parser.byte;
		}
		
		if (parser.partial) {
			length = parser.nextPartialLength;
		} else {
			length = 0;
		}
	}
	
	self.content = tempData;
	
	
	return self;
}

- (GPGPacketTag)tag {
	return 11;
}

- (void)dealloc {
	self.filename = nil;
	self.date = nil;
	self.content = nil;
	[super dealloc];
}


@end

