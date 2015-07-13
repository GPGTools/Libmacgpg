/* GPGPacketParser.m
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

#import "GPGPacketParser.h"
#import "GPGStream.h"
#import "GPGGlobals.h"
#import "GPGException.h"
#import "GPGPacket.h"
#import "GPGPacket_Private.h"
#import "GPGPublicKeyEncryptedSessionKeyPacket.h"
#import "GPGSignaturePacket.h"
#import "GPGSymmetricEncryptedSessionKeyPacket.h"
#import "GPGOnePassSignaturePacket.h"
#import "GPGKeyMaterialPacket.h"
#import "GPGIgnoredPackets.h"
#import "GPGLiteralDataPacket.h"
#import "GPGUserIDPacket.h"
#import "GPGUserAttributePacket.h"
#import "GPGCompressedDataPacket_Private.h"


#define BINARY_TAG_FLAG 0x80
#define NEW_TAG_FLAG    0x40
#define TAG_MASK        0x3f
#define PARTIAL_MASK    0x1f
#define TAG_COMPRESSED  8

#define OLD_TAG_SHIFT   2
#define OLD_LEN_MASK    0x03

#define CRITICAL_BIT    0x80
#define CRITICAL_MASK   0x7f

static NSString * const endOfFileException = @"endOfFileException";
static NSArray *tagClasses = nil;

@interface GPGPacketParser ()
@property (nonatomic, readwrite, strong) NSError *error;
@property (nonatomic, strong) GPGStream *stream;
@property (nonatomic, strong) GPGCompressedDataPacket *compressedPacket;
@end


@implementation GPGPacketParser
@synthesize stream, compressedPacket;
@synthesize error;
@synthesize byteCallback;

#pragma mark Main methods

- (GPGPacket *)nextPacket {
	@try {
		if (compressedPacket.canDecompress) {
			// We have a compressed packet, get the next decompressed packet.
			GPGPacket *tempPacket = [compressedPacket nextPacket];
			if (tempPacket) {
				return tempPacket;
			} else {
				self.compressedPacket = nil;
			}
		}
		
		NSInteger c = [stream readByte];
		if (c == EOF) {
			self.error = nil;
			return nil;
		}
		if ((c & BINARY_TAG_FLAG) == 0) {
			self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorInvalidData userInfo:nil];
			return nil;
		}
		
		
		NSInteger tag = c & TAG_MASK;
		NSUInteger len = 0;
		partial = NO;
		
		if (c & NEW_TAG_FLAG) {
			// New format.
			c = self.byte;
			len = [self getNewLen:c];
			partial = isPartial(c);
			if (partial && len < 512) {
				self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorBadData userInfo:nil];
				return nil;
			}
		} else {
			// Old format.
			NSUInteger tlen;
			
			tlen = c & OLD_LEN_MASK;
			tag >>= OLD_TAG_SHIFT;
			
			switch (tlen) {
				case 0:
					len = self.byte;
					break;
				case 1:
					len = (self.byte << 8);
					len += self.byte;
					break;
				case 2:
					len = self.byte << 24;
					len |= self.byte << 16;
					len |= self.byte << 8;
					len |= self.byte;
					break;
				case 3:
					len = NSUIntegerMax;
					break;
			}
		}
		
		GPGPacket *packet = nil;
		Class class = nil;
		
		if (tag < tagClasses.count) {
			class = tagClasses[tag];
			if (class == [NSNull null]) {
				class = nil;
				[self skip:len];
			} else {
				packetLength = len;
				packet = [[[class alloc] initWithParser:self length:len] autorelease];
				
				if (tag == TAG_COMPRESSED && [(GPGCompressedDataPacket *)packet canDecompress]) {
					self.compressedPacket = (GPGCompressedDataPacket *)packet;
					
					GPGPacket *tempPacket = [compressedPacket nextPacket];
					if (tempPacket) {
						return tempPacket;
					} else {
						self.compressedPacket = nil;
					}
				}
			}
		} else {
			[self skip:len];
		}
		
		while (partial == YES) {
			c = self.byte;
			len = [self getNewLen:c];
			partial = isPartial(c);
			
			[self skip:len];
		}
		
		return packet;
	} @catch (NSException *exception) {
		if ([exception.name isEqualToString:endOfFileException]) {
			self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorEOF userInfo:nil];
		} else {
			@throw;
		}
	}

	return nil;
}


#pragma mark Helper

- (NSInteger)byte {
	NSInteger byte = [stream readByte];
	if (byte == EOF) {
		@throw [NSException exceptionWithName:endOfFileException reason:@"unexpected end of file." userInfo:nil];
	}
	
	packetLength--;
	
	if (byteCallback) {
		byteCallback(byte);
	}

	return byte;
}

- (NSInteger)byteOrEOF {
	NSInteger byte = [stream readByte];
	packetLength--;
	
	if (byteCallback && byte != EOF) {
		byteCallback(byte);
	}
	
	return byte;
}

- (void)skip:(NSUInteger)count {
	for (; count > 0; count--) {
		[self byte];
	}
}

static BOOL isPartial(NSInteger c) {
	if (c < 224 || c == 255) {
		return NO;
	} else {
		return YES;
	}
}

- (NSUInteger)getNewLen:(NSInteger)c {
	NSUInteger len;
	
	if (c < 192) {
		len = c;
	} else if (c < 224) {
		len = ((c - 192) << 8) + self.byte + 192;
	} else if (c == 255) {
		len = (self.byte << 24);
		len |= (self.byte << 16);
		len |= (self.byte << 8);
		len |= self.byte;
	} else {
		len = 1 << (c & PARTIAL_MASK);
	}
	return len;
}


#pragma mark Parsing methods, used by GPGPacket

- (NSUInteger)nextPartialLength {
	if (partial == NO) {
		return 0;
	}
	
	NSInteger c = self.byte;
	NSUInteger length = [self getNewLen:c];
	partial = isPartial(c);
	
	return length;
}

- (BOOL)partial {
	return partial;
}

- (void)skipRemaining {
	[self skip:packetLength];
}

- (NSString *)keyID {
	NSString *keyID = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X",
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte,
					   (UInt8)self.byte];
	
	return keyID;
}

- (id)multiPrecisionInteger {
	NSUInteger byteCount;
	NSUInteger bits = self.byte * 256;
	bits += self.byte;
	byteCount = (bits + 7) / 8;
	
	NSMutableData *data = [NSMutableData dataWithLength:byteCount];
	UInt8 *bytes = data.mutableBytes;
	
	for (NSUInteger i = 0; i < byteCount; i++) {
		bytes[i] = (UInt8)self.byte;
	}
	
	
	return data;
}

- (NSDate *)date {
	NSUInteger time;
	
	time = self.byte << 24;
	time |= self.byte << 16;
	time |= self.byte << 8;
	time |= self.byte;
	
	if (time == 0) {
		return nil;
	}
	
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
	
	return date;
}

- (UInt16)uint16 {
	UInt16 value = (UInt16)((self.byte << 8) | self.byte);
	return value;
}

- (NSString *)stringWithLength:(NSUInteger)length {
	char tempString[length + 1];
	tempString[length] = 0;
	for (NSUInteger i = 0; i < length; i++) {
		tempString[i] = (char)self.byte;
	}
	
	NSString *string = [NSString stringWithUTF8String:tempString];
	
	return string;
}

- (NSArray *)signatureSubpacketsWithLength:(NSUInteger)fullLength {
	NSMutableArray *packets = [NSMutableArray array];
	
	while (fullLength > 0) {
		NSUInteger length = self.byte;
		if (length < 192) {
			fullLength--;
		} else if (length < 255) {
			length = ((length - 192) << 8) + self.byte + 192;
			fullLength -= 2;
		} else if (length == 255) {
			length = self.byte << 24;
			length |= self.byte << 16;
			length |= self.byte << 8;
			length |= self.byte;
			fullLength -= 5;
		}
		fullLength -= length;
		
		
		NSUInteger remainingLength = packetLength - length;

		
		GPGSubpacketTag subtag = self.byte; /* len includes this field byte */
		length--;
		
		/* Handle critical bit of subpacket type */
		BOOL critical = NO;
		if (subtag & CRITICAL_BIT) {
			critical = YES;
			subtag &= CRITICAL_MASK;
		}
		
		
		NSMutableDictionary *packet = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(subtag), @"tag", nil];
		
		if (critical) {
			packet[@"critical"] = @YES;
		}
		
		
		switch (subtag) {
			case GPGSignatureCreationTimeTag:
			case GPGSignatureExpirationTimeTag:
			case GPGKeyExpirationTimeTag: {
				NSDate *date = [self date];
				if (date) {
					packet[@"date"] = date;
				}
				break;
			}
			case GPGIssuerTag: {
				NSString *keyID = [self keyID];
				if (keyID) {
					packet[@"keyID"] = keyID;
				}
				break;
			}
			case GPGPolicyURITag:
			case GPGPreferredKeyServerTag:
			case GPGSignersUserIDTag: {
				NSString *string = [self stringWithLength:length];
				if (string) {
					if (subtag == GPGSignersUserIDTag) {
						packet[@"userID"] = string;
					} else {
						packet[@"URI"] = string;
					}
				}
				break;
			}
			case GPGPrimaryUserIDTag: {
				BOOL primary = !!self.byte;
				packet[@"primary"] = @(primary);
				break;
			}
			case GPGKeyFlagsTag: {
				NSInteger flags = self.byte;
				
				packet[@"canCertify"] = @(!!(flags & 0x01));
				packet[@"canSign"] = @(!!(flags & 0x02));
				packet[@"canEncryptCommunications"] = @(!!(flags & 0x04));
				packet[@"canEncryptStorage"] = @(!!(flags & 0x08));
				packet[@"maySplitted"] = @(!!(flags & 0x10));
				packet[@"canAuthentication"] = @(!!(flags & 0x20));
				packet[@"multipleOwners"] = @(!!(flags & 0x80));
				
				break;
			}
			case GPGReasonForRevocationTag: {
				packet[@"code"] = @(self.byte);
				NSString *string = [self stringWithLength:length - 1];
				if (string) {
					packet[@"reason"] = string;
				}
				break;
			}
			case GPGSignatureTargetTag: {
				packet[@"publicAlgorithm"] = @(self.byte);
				packet[@"hashAlgorithm"] = @(self.byte);
				length -= 2;
				
				NSMutableData *data = [NSMutableData dataWithLength:length];
				if (data) {
					UInt8 *bytes = data.mutableBytes;
					
					for (NSUInteger i = 0; i < length; i++) {
						bytes[i] = (UInt8)self.byte;
					}
					
					packet[@"hash"] = [[data copy] autorelease];
				}
				break;
			}
			default:
				break;
		}
		
		[packets addObject:packet];
		
		
		length = packetLength - remainingLength;
		[self skip:length];
	}

	
	return packets;
}


#pragma mark init etc.

+ (instancetype)packetParserWithStream:(GPGStream *)stream {
	return [[(GPGPacketParser *)[self alloc] initWithStream:stream] autorelease];
}

- (instancetype)initWithStream:(GPGStream *)theStream {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.stream = theStream;
	
	return self;
}

+ (void)initialize {
	tagClasses = [@[
				   [NSNull null],
				   [GPGPublicKeyEncryptedSessionKeyPacket class], // 1
				   [GPGSignaturePacket class], // 2
				   [GPGSymmetricEncryptedSessionKeyPacket class], // 3
				   [GPGOnePassSignaturePacket class], // 4
				   [GPGSecretKeyPacket class], // 5
				   [GPGPublicKeyPacket class], // 6
				   [GPGSecretSubkeyPacket class], // 7
				   [GPGCompressedDataPacket class], // 8
				   [GPGEncryptedDataPacket class], // 9
				   [GPGMarkerPacket class], // 10
				   [GPGLiteralDataPacket class], // 11
				   [GPGTrustPacket class], // 12
				   [GPGUserIDPacket class], // 13
				   [GPGPublicSubkeyPacket class], // 14
				   [NSNull null], // 15
				   [NSNull null], // 16
				   [GPGUserAttributePacket class], // 17
				   [GPGEncryptedProtectedDataPacket class] // 18
				   ] retain];
}

- (void)dealloc {
	self.stream = nil;
	self.error = nil;
	self.compressedPacket = nil;
	self.byteCallback = nil;
	[super dealloc];
}


@end
