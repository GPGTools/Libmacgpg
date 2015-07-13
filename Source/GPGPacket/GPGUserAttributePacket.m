/* GPGUserAttributePacket.m
 Based on pgpdump (https://github.com/kazu-yamamoto/pgpdump) from Kazuhiko Yamamoto.
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

#import "GPGUserAttributePacket.h"
#import "GPGPacket_Private.h"

@interface GPGUserAttributePacket ()
@property (nonatomic, copy, readwrite) NSArray *subpackets;
@end


@implementation GPGUserAttributePacket
@synthesize subpackets;


- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	NSMutableArray *packets = [NSMutableArray array];
	NSUInteger fullLength = length;
	
	while (fullLength > 0) {
		
		NSUInteger subLength = parser.byte;
		
		if (subLength < 192) {
			fullLength--;
		} else if (subLength < 255) {
			subLength = ((subLength - 192) << 8) + parser.byte + 192;
			fullLength -= 2;
		} else if (subLength == 255) {
			subLength = parser.byte << 24;
			subLength |= parser.byte << 16;
			subLength |= parser.byte << 8;
			subLength |= parser.byte;
			fullLength -= 5;
		}
		fullLength -= subLength;
		NSInteger subtype = parser.byte; /* len includes this field byte */
		subLength--;
		
		
		
		switch (subtype) {
			case 1: {
				
				NSUInteger headerLength = parser.byte;
				headerLength |= parser.byte << 8; // little-endian, because of a "historical accident"!
				
				NSInteger headerVersion = parser.byte;
				subLength -= 3;
				
				if (headerLength == 16 && headerVersion == 1) {
					NSInteger format = parser.byte;
					subLength--;
					
					if (format == 1) { // JPEG is the only currently defined format.
						[parser skip:12];
						subLength -= 12;
						
						NSMutableData *tempData = [NSMutableData dataWithLength:subLength];
						UInt8 *bytes = tempData.mutableBytes;
						for (NSUInteger i = 0; i < subLength; i++) {
							bytes[i] = (UInt8)parser.byte;
						}
						
						subLength = 0;
						
						NSImage *image = [[NSImage alloc] initWithData:tempData];
						
						if (image) {
							NSDictionary *subpacket = @{@"image": image};
							[packets addObject:subpacket];
						}
					}
				}
				break;
			}
			default:
				break;
		}
		
		[parser skip:subLength];
	}

	self.subpackets = packets;
	
	return self;
}

- (GPGPacketTag)tag {
	return 17;
}

- (void)dealloc {
	self.subpackets = nil;
	[super dealloc];
}


@end

