/*
 Copyright © Roman Zechmeister, 2014
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
 */

#import "GPGPacket.h"
#import "GPGMemoryStream.h"
#import "GPGGlobals.h"
#import "GPGException.h"
#include <string.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#import "GPGUnArmor.h"

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>


#define readUint8 (*((*((uint8_t**)&readPos))++))
#define readUint16 CFSwapInt16BigToHost(*((*((uint16_t**)&readPos))++))
#define readUint32 CFSwapInt32BigToHost(*((*((uint32_t**)&readPos))++))
#define readUint64 CFSwapInt64BigToHost(*((*((uint64_t**)&readPos))++))
#define abortInit [self release]; return nil;
#define abortSwitch type = 0; break;
#define canRead(x) if (readPos-bytes+(x) > dataLength) {goto endOfBuffer;}





@interface GPGPacket ()
- (id)initWithBytes:(const uint8_t *)bytes length:(NSUInteger)dataLength nextPacketStart:(const uint8_t **)nextPacket;

@end




@implementation GPGPacket
@synthesize type, data, keyID, fingerprint, publicKeyAlgorithm, symetricAlgorithm, hashAlgorithm, signatureType, subpackets;



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
	const uint8_t *bytes = theData.bytes;
	
	
	const uint8_t *endPos = bytes + theData.length;
	const uint8_t *currentPos = bytes;
	const uint8_t *nextPacketPos = 0;
	BOOL stop = NO;
	
	while (currentPos < endPos) {
		nextPacketPos = 0;
		GPGPacket *packet = [[self alloc] initWithBytes:currentPos length:endPos - currentPos nextPacketStart:&nextPacketPos];
		if (packet) {
			block(packet, &stop);
			[packet release];
			if (stop) {
				[theData release];
				return;
			}
		}
		if (nextPacketPos <= currentPos) {
			break;
		}
		currentPos = nextPacketPos;
	}

	[theData release];
}

- (id)initWithBytes:(const uint8_t *)bytes length:(NSUInteger)dataLength nextPacketStart:(const uint8_t **)nextPacket {
	if (!(self = [super init])) {
		return nil;
	}
	description = nil;
	
	const uint8_t *readPos = bytes;
	canRead(1);
	
	if (!(bytes[0] & 0x80)) {
		[self release];
		return nil;
	}
	
	BOOL newFormat = bytes[0] & 0x40;
	unsigned int length;
	
	if (newFormat) {
		type = *readPos & 0x3F;
		readPos++;
		const uint8_t *oldReadPos = readPos;
		
		length = 0;
		while (1) {
			canRead(1);
			if (*readPos < 192) {
				length += *readPos;
				readPos = oldReadPos + 1;
				break;
			} else if (*readPos < 224) {
				canRead(2);
				length += ((readPos[0] - 192) << 8) + readPos[1] + 192;
				readPos = oldReadPos + 2;
				break;
			} else if (*readPos == 255) {
				readPos++;
				canRead(4);
				length += readUint32;
				readPos = oldReadPos + 4;
				break;
			}
			//TODO: Full support for Partial Packets.
			unsigned int partLength = (1 << (*readPos & 0x1F)) + 1;
			readPos += partLength;
			length += partLength;
		}
		
	} else {
		type = (*readPos & 0x3C) >> 2;
		if (type == 0) {
			abortInit;
		}
		switch (*(readPos++) & 3) {
			case 0:
				canRead(1);
				length = readUint8;
				break;
			case 1:
				canRead(2);
				length = readUint16;
				break;
			case 2:
				canRead(4);
				length = readUint32;
				break;
			default:
				length = dataLength - 1;
				break;
		}
	}
	canRead(length);
	data = [[NSData alloc] initWithBytes:bytes length:readPos - bytes + length];
	
	*nextPacket = readPos + length;
	
	
	
	
	switch (type) { //TODO: Parse packet content.
		case GPGPublicKeyEncryptedSessionKeyPacket:
			canRead(10);
			if (readUint8 != 3) {
				abortSwitch;
			}
			keyID = [[NSString alloc] initWithFormat:@"%016llX", readUint64];
			publicKeyAlgorithm = readUint8;
			break;
		case GPGSignaturePacket:
			canRead(12);
			switch (readUint8) {
				case 3:
					//TODO
					break;
				case 4: {
					signatureType = readUint8;
					publicKeyAlgorithm = readUint8;
					hashAlgorithm = readUint8;
					
					
					
					// Subpackets verarbeiten.
					subpackets = [[NSMutableArray alloc] init];
					
					for (int i = 0; i < 2; i++) { // Zweimal da es hashed und unhashed subpackets geben kann!
						const uint8_t *subpacketEnd = readUint16 + readPos;
						while (readPos < subpacketEnd) {
							NSMutableDictionary *subpacket = [[NSMutableDictionary alloc] init];
							
							uint32_t subpacketLength = readUint8;
							if (subpacketLength == 255) {
								subpacketLength = readUint32;
							} else if (subpacketLength >= 192) {
								subpacketLength = ((subpacketLength - 192) << 8) + readUint8 + 192;
							}
							uint8_t subpacketType = readUint8;
							
							[subpacket setObject:@(subpacketLength) forKey:@"length"];
							[subpacket setObject:@(subpacketType) forKey:@"type"];
														
							if (subpacketType == 16 && subpacketLength == 9) {
								keyID = [bytesToHexString(readPos, 8) retain];
							}
							
							
							[subpackets addObject:subpacket];
							[subpacket release];
							
							readPos += subpacketLength - 1;
						}
					}
					
					
					break; }
			}
			break;
		case GPGSymmetricEncryptedSessionKeyPacket:
			canRead(2);
			if (readUint8 != 3) {
				abortSwitch;
			}
			symetricAlgorithm = readUint8;
			break;
		case GPGOnePassSignaturePacket:
			canRead(13);
			if (readUint8 != 4) {
				abortSwitch;
			}
			signatureType = readUint8;
			hashAlgorithm = readUint8;
			publicKeyAlgorithm = readUint8;
			keyID = [[NSString alloc] initWithFormat:@"%016llX", readUint64];
			break;
		case GPGPublicKeyPacket:
		case GPGPublicSubkeyPacket:
		case GPGSecretKeyPacket:
		case GPGSecretSubkeyPacket: {
			const uint8_t *packetStart = readPos;
			canRead(6);
			if (readUint8 != 4) {
				abortSwitch;
			}
			readPos += 4;
			publicKeyAlgorithm = readUint8;
			
			
			uint8_t bytesForSHA1[length + 3];
			bytesForSHA1[0] = 0x99;
			uint16_t temp = (uint16_t)length;
			bytesForSHA1[1] = ((uint8_t*)&temp)[1];
			bytesForSHA1[2] = ((uint8_t*)&temp)[0];
			memcpy(bytesForSHA1+3, packetStart, length);
			
			uint8_t fingerprintBytes[20];
			CC_SHA1(bytesForSHA1, length + 3, fingerprintBytes);
			fingerprint = [bytesToHexString(fingerprintBytes, 20) retain];
			keyID = [[fingerprint keyID] retain];
			
			break; }
		case GPGCompressedDataPacket:
			//TODO
			break;
		case GPGSymmetricEncryptedDataPacket:
			//TODO
			break;
		case GPGMarkerPacket:
			//TODO
			break;
		case GPGLiteralDataPacket:
			//TODO
			break;
		case GPGTrustPacket:
			//TODO
			break;
		case GPGUserIDPacket:
			//TODO
			break;
		case GPGUserAttributePacket:
			//TODO
			break;
		case GPGSymmetricEncryptedProtectedDataPacket:
			//TODO
			break;
		case GPGModificationDetectionCodePacket:
			//TODO
			break;
		default: //Unknown packet type.
			abortSwitch;
	}
	
	
	return self;
endOfBuffer:
	abortInit;
}

- (id)init {
	[self release];
	return nil;
}

- (void)dealloc {
	[data release];
	[fingerprint release];
	[keyID release];
	[description release];
	[subpackets release];
	
	[super dealloc];
}

- (NSString *)description {
	if (!description) {
		description = [[NSString alloc] initWithFormat:@"GPGPacket type: %i, keyID %@", self.type, self.keyID];
	}

	return [[description retain] autorelease];
}



// Old methods, only for compatibility.

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
