/* GPGCompressedDataPacket.m
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

#import "GPGCompressedDataPacket.h"
#import "GPGCompressedDataPacket_Private.h"
#import "GPGPacket_Private.h"
#import "GPGPacketParser.h"
#import "GPGStream.h"
#import <zlib.h>
#import <bzlib.h>


@interface GPGDecompressStream : GPGStream {
	GPGPacketParser *parser;
	NSInteger algorithm;
	z_stream zStream;
	bz_stream bzStream;
	
	NSUInteger packetLength;
	
	BOOL streamEnd;
	NSUInteger availablePacketBytes;
	NSMutableData *inputData;
	UInt8 *inputBytes;
	NSUInteger inputSize;
	
	NSMutableData *cacheData;
	UInt8 *cacheBytes;
	
	NSUInteger cacheLocation;
	NSUInteger cacheAvailableBytes;
}
- (instancetype)initWithParser:(GPGPacketParser *)parser length:(NSUInteger)length algorithm:(NSInteger)algorithm;
@end



@interface GPGCompressedDataPacket ()
@property (nonatomic, readwrite) NSInteger compressAlgorithm;
@property (nonatomic, strong, readwrite) GPGDecompressStream *decompressStream;
@property (nonatomic, strong) GPGPacketParser *subParser;
@end


@implementation GPGCompressedDataPacket
@synthesize compressAlgorithm, decompressStream, subParser;

- (instancetype)initWithParser:(GPGPacketParser *)theParser length:(NSUInteger)length {
	self = [super init];
	if (!self) {
		return nil;
	}
	self.compressAlgorithm = theParser.byte;
	length--;
	
	switch (compressAlgorithm) {
		case 0:
		case 1:
		case 2:
		case 3:
			break;
		default:
			[theParser skip:length];
			return self;
	}
	
	self.decompressStream = [[GPGDecompressStream alloc] initWithParser:theParser length:length algorithm:compressAlgorithm];
	if (decompressStream) {
		self.subParser = [[GPGPacketParser alloc] initWithStream:self.decompressStream];
	}
	
	return self;
}

- (GPGPacket *)nextPacket {
	GPGPacket *packet = [subParser nextPacket];
	if (!packet) {
		self.decompressStream = nil;
		self.subParser = nil;
	}
	return packet;
}

- (BOOL)canDecompress {
	return !!subParser;
}

- (GPGPacketTag)tag {
	return 8;
}

- (void)dealloc {
	self.decompressStream = nil;
	self.subParser = nil;
	[super dealloc];
}
@end



@implementation GPGDecompressStream
const NSUInteger cacheSize = 1024 * 32;

- (void)dealloc {
	[cacheData release];
	[inputData release];
	[parser release];
	[super dealloc];
}

- (instancetype)initWithParser:(GPGPacketParser *)theParser length:(NSUInteger)length algorithm:(NSInteger)theAlgorithm {
	self = [super init];
	if (!self) {
		return nil;
	}

	
	parser = [theParser retain];
	algorithm = theAlgorithm;
	packetLength = length;
	availablePacketBytes = packetLength;

	inputData = [[NSMutableData alloc] initWithLength:cacheSize];
	cacheData = [[NSMutableData alloc] initWithLength:cacheSize];

	int status = 0;

	switch (algorithm) {
		case 0:
			// No compresseion.
			[inputData release];
			inputData = [cacheData retain];
			break;
		case 1:
			status = inflateInit2(&zStream, -13);
			break;
		case 2:
			status = inflateInit(&zStream);
			break;
		case 3:
			status = BZ2_bzDecompressInit(&bzStream, 0, 0);
			break;
	}
	
	if (status != 0) {
		[self release];
		return nil;
	}
	
	inputBytes = inputData.mutableBytes;
	cacheBytes = cacheData.mutableBytes;
	

	return self;
}

- (void)fillInput {
	inputSize = 0;
	if (packetLength != 0) {
		for (; inputSize < cacheSize; inputSize++) {
			NSInteger byte = parser.byteOrEOF;
			if (byte == EOF) {
				break;
			}
			inputBytes[inputSize] = (UInt8)byte;
			availablePacketBytes--;
			
			if (availablePacketBytes == 0) {
				if (parser.partial) {
					packetLength = parser.nextPartialLength;
					availablePacketBytes = packetLength;
				} else {
					packetLength = 0;
				}
				if (packetLength == 0) {
					// We have no more data.
					break;
				}
			}
		}
	}

}

- (BOOL)zlibFillCache {
	zStream.avail_out = cacheSize;
	zStream.next_out = cacheBytes;
	
	do {
		if (zStream.avail_in == 0) {
			// We need more input Data, fill the buffer.
			[self fillInput];
			zStream.avail_in = inputSize;
			zStream.next_in = inputBytes;
		}
		
		
		int status = inflate(&zStream, Z_SYNC_FLUSH);
		
		if (status != Z_OK) {
			inflateEnd(&zStream);
			streamEnd = YES;
			if (status != Z_STREAM_END) {
				return NO;
			}
		}
		
	} while (zStream.avail_out == cacheSize);
	
	
	cacheAvailableBytes = cacheSize - zStream.avail_out;
	
	return YES;
}

- (BOOL)bzFillCache {
	bzStream.avail_out = cacheSize;
	bzStream.next_out = (char *)cacheBytes;
	
	do {
		if (bzStream.avail_in == 0) {
			// We need more input Data, fill the buffer.
			[self fillInput];
			bzStream.avail_in = inputSize;
			bzStream.next_in = (char *)inputBytes;
		}
		
		int status = BZ2_bzDecompress(&bzStream);
		
		if (status != BZ_OK) {
			BZ2_bzDecompressEnd(&bzStream);
			streamEnd = YES;
			if (status != BZ_STREAM_END) {
				return NO;
			}
		}
		
	} while (bzStream.avail_out == cacheSize);
	
	
	cacheAvailableBytes = cacheSize - bzStream.avail_out;
	
	return YES;
}

- (BOOL)uncompressedFillCache {
	[self fillInput];
	
	if (inputSize == 0) {
		streamEnd = YES;
		return NO;
	}
	cacheAvailableBytes = inputSize;
	
	return YES;
}

- (NSInteger)readByte {
	if (cacheAvailableBytes == 0) {
		if (streamEnd) {
			return EOF;
		}
		cacheLocation = 0;
		
		BOOL moreData = NO;
		
		switch (algorithm) {
			case 0:
				moreData = [self uncompressedFillCache];
				break;
			case 1:
			case 2:
				moreData = [self zlibFillCache];
				break;
			case 3:
				moreData = [self bzFillCache];
				break;
		}
		if (streamEnd) {
			[parser release];
			parser = nil;
		}
		if (!moreData) {
			return EOF;
		}

	}
	
	cacheAvailableBytes--;
	return cacheBytes[cacheLocation++];
}

@end
