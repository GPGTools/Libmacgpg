/* GPGPacket.m
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

#import "GPGPacket.h"
#import "GPGPacket_Private.h"
#import "GPGPacketParser.h"

#import "GPGMemoryStream.h"
#import "GPGUnArmor.h"


@implementation GPGPacket

- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length {
	return [super init];
}
- (GPGPacketTag)tag {
	return 0;
}







// Old methods, only for compatibility.

- (NSInteger)type {
	return self.tag;
}
- (NSString *)keyID {
	return nil;
}
- (NSInteger)signatureType {
	if (self.tag == GPGSignaturePacketTag) {
		return [self type];
	} else {
		return 0;
	}
}


+ (id)packetsWithData:(NSData *)theData {
	NSMutableArray *packets = [NSMutableArray array];
	
	[self enumeratePacketsWithData:theData block:^(GPGPacket *packet, BOOL *stop) {
		[packets addObject:packet];
	}];
	
	return packets;
}

+ (void)enumeratePacketsWithData:(NSData *)theData block:(void (^)(GPGPacket *packet, BOOL *stop))block {
	theData = [theData copy];
	
	if (theData.isArmored) {
		GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:theData];
		GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
		
		[unArmor decodeAll];
		
		[theData release];
		theData = [unArmor.data retain];
	}
	
	if (theData.length < 10) {
		[theData release];
		return;
	}
	
	GPGMemoryStream *stream = [[GPGMemoryStream alloc] initForReading:theData];
	GPGPacketParser *parser = [[GPGPacketParser alloc] initWithStream:stream];
	GPGPacket *packet;
	
	while ((packet = [parser nextPacket])) {
		BOOL stop = NO;
		block(packet, &stop);
		if (stop) {
			break;
		}
	}
	
	[parser release];
	[stream release];
	[theData release];
}

// if return nil, input stream is not armored; should be reset and used directly
+ (NSData *)unArmor:(NSData *)data {
	return [self unArmor:data clearText:nil];
}
+ (NSData *)unArmor:(NSData *)data clearText:(NSData **)clearText {
	GPGMemoryStream *stream = [GPGMemoryStream memoryStreamForReading:data];
	GPGUnArmor *unArmor = [GPGUnArmor unArmorWithGPGStream:stream];
	
	[unArmor decodeAll];
	
	if (clearText) {
		*clearText = unArmor.clearText;
	}
	
	return unArmor.data;
}





@end
