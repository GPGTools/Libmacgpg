/*
 Copyright © Roman Zechmeister, 2011
 
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
#import "GPGGlobals.h"
#include <openssl/bio.h>
#include <openssl/evp.h>

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>


#define readUint8 (*((*((uint8_t**)&readPos))++))
#define readUint16 CFSwapInt16BigToHost(*((*((uint16_t**)&readPos))++))
#define readUint32 CFSwapInt32BigToHost(*((*((uint32_t**)&readPos))++))
#define readUint64 CFSwapInt64BigToHost(*((*((uint64_t**)&readPos))++))
#define abortInit [self release]; return nil;
#define abortSwitch type = 0; break;
#define canRead(x) if (readPos-bytes+(x) > dataLength) {goto endOfBuffer;}



@interface GPGPacket (Private)

- (id)initWithBytes:(const uint8_t *)bytes length:(NSUInteger)length previousPacket:(GPGPacket *)previousPacket;
- (BOOL)isArmored:(const uint8_t)byte;
- (NSData *)unArmor:(NSData *)theData;

@end


typedef enum {
	state_searchStart = 0,
	state_parseStart,
	state_waitForText,
	state_waitForEnd
} myState;



@implementation GPGPacket
@synthesize previousPacket, nextPacket, type, data, keyID, fingerprint, publicKeyAlgorithm, symetricAlgorithm, hashAlgorithm, signatureType;



static const char armorBeginMark[] = "\n-----BEGIN PGP ";
const int armorBeginMarkLength = 16;
static const char armorEndMark[] = "\n-----END PGP ";
const int armorEndMarkLength = 14;
static const char *armorTypeStrings[] = { //The first byte contains the length of the string.
	"\x13SIGNED MESSAGE-----",
	"\x0cMESSAGE-----",
	"\x15PUBLIC KEY BLOCK-----",
	"\x0eSIGNATURE-----",
	"\021ARMORED FILE-----",
	"\x16PRIVATE KEY BLOCK-----",
	"\x15SECRET KEY BLOCK-----"
};
const int armorTypeStringsCount = 7;



+ (id)packetWithData:(NSData *)theData {
	return [[[self alloc] initWithData:theData] autorelease];
}


- (id)initWithData:(NSData *)theData {
	const uint8_t *bytes = [theData bytes];
	NSUInteger dataLength = [theData length];
	if (dataLength < 10) {
		abortInit;
	}
	if ([self isArmored:bytes[0]]) {
		theData = [self unArmor:theData];
		if (!theData || [theData length] < 10) {
			abortInit;
		}
		bytes = [theData bytes];
		dataLength = [theData length];
	}
	return [self initWithBytes:bytes length:dataLength previousPacket:nil];
}


- (NSData *)unArmor:(NSData *)theData {
	const char *bytes = [theData bytes];
	NSUInteger dataLength = [theData length];
	const char *readPos = bytes;
	const char *endPos = bytes + dataLength;
	int newlineCount, armorType;
	BOOL found;
	NSMutableData *decodedData = [NSMutableData data];
	myState state = state_searchStart;
	
	
	if (memcmp(armorBeginMark+1, readPos, armorBeginMarkLength - 1) == 0) {
		state = state_parseStart;
		readPos += armorBeginMarkLength - 1;
	}
	
	for (;readPos < endPos - 25; readPos++) {
		switch (state) {
			case state_searchStart:
				if (memcmp(armorBeginMark, readPos, armorBeginMarkLength) != 0) {
					break;
				}
				readPos += armorBeginMarkLength;
				state = state_parseStart;
			case state_parseStart:
				canRead(40);
				found = NO;
				for (armorType = 0; armorType < armorTypeStringsCount; armorType++) {
					if (memcmp(armorTypeStrings[armorType]+1, readPos, armorTypeStrings[armorType][0]) == 0) {
						readPos += armorTypeStrings[armorType][0] - 1;
						if (armorType != 0) { //Is not "-----BEGIN PGP SIGNED MESSAGE-----".
							found = YES;
						}
						break;
					}
				}
				if (!found) {
					state = state_searchStart;
					break;
				}
				state = state_waitForText;
				newlineCount = 0;
				readPos++;
			case state_waitForText:
				switch (*readPos) {
					case '\n':
						newlineCount++;
						if (newlineCount == 2) {
							state = state_waitForEnd;
						}						
					case '\r':
					case ' ':
					case '\t':
						break;
					default:
						newlineCount = 0;
				}
				break;
			case state_waitForEnd: {
				const char *textStart = readPos;
				const char *textEnd = strnstr(readPos, "\n=", endPos - readPos);
				if (!textEnd) {
					goto endOfBuffer;
				}
				textEnd++;
				readPos = strnstr(textEnd, armorEndMark, endPos - textEnd);
				if (!readPos) {
					goto endOfBuffer;
				}
				
				readPos = readPos + armorEndMarkLength;
				int length = armorTypeStrings[armorType][0];
				canRead(length);
				if (memcmp(armorTypeStrings[armorType]+1, readPos, armorTypeStrings[armorType][0]) != 0) {
					goto endOfBuffer;
				}
				
				length = (textEnd - textStart) * 3 / 4;
				char *binaryBuffer = malloc(length);
				if (!binaryBuffer) {
					goto endOfBuffer;
				}
				
				BIO *filter = BIO_new(BIO_f_base64());
				BIO *bio = BIO_new_mem_buf((void *)textStart, textEnd - textStart);
				bio = BIO_push(filter, bio);
				length = BIO_read(bio, binaryBuffer, length);
				BIO_free_all(bio);
				
				if (length > 0) {
					[decodedData appendBytes:binaryBuffer length:length];
				}
				free(binaryBuffer);
				
				
				readPos += armorTypeStrings[armorType][0];
				state = state_searchStart;
				break; }
		}		
	}
	
endOfBuffer:
	return decodedData;
}




- (id)initWithBytes:(const uint8_t *)bytes length:(NSUInteger)dataLength previousPacket:(GPGPacket *)prevPacket {
	if (!(self = [super init])) {
		return nil;
	}
	previousPacket = prevPacket;
	
	const uint8_t *readPos = bytes;
	canRead(1);
	
	
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
				abortInit;
		}
	}
	canRead(length);
	data = [[NSData alloc] initWithBytes:bytes length:readPos - bytes + length];
	
	const uint8_t *nextPacketBytes = readPos + length;
	NSUInteger nextPacketDataLength = dataLength - (readPos - bytes) - length;
	
	
	
	
	switch (type) { //TODO: Parse packet content.
		case GPGPublicKeyEncryptedSessionKeyPacket:
			canRead(10);
			if (readUint8 != 3) {
				abortSwitch;
			}
			keyID = [[NSString alloc] initWithFormat:@"%qX", readUint64];
			publicKeyAlgorithm = readUint8;
			break;
		case GPGSignaturePacket:
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
			keyID = [[NSString alloc] initWithFormat:@"%qX", readUint64];
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
			uint16_t temp = length;
			bytesForSHA1[1] = ((uint8_t*)&temp)[1];
			bytesForSHA1[2] = ((uint8_t*)&temp)[0];
			memcpy(bytesForSHA1+3, packetStart, length);
			
			uint8_t fingerprintBytes[20];
			CC_SHA1(bytesForSHA1, length + 3, fingerprintBytes);
			fingerprint = [bytesToHexString(fingerprintBytes, 20) retain];
			keyID = [[fingerprint keyID] retain];
			
			break; }
		case GPGCompressedDataPacket:
			break;
		case GPGSymmetricEncryptedDataPacket:
			break;
		case GPGMarkerPacket:
			break;
		case GPGLiteralDataPacket:
			break;
		case GPGTrustPacket:
			break;
		case GPGUserIDPacket:
			break;
		case GPGUserAttributePacket:
			break;
		case GPGSymmetricEncryptedProtectedDataPacket:
			break;
		case GPGModificationDetectionCodePacket:
			break;
		default: //Unknown packet type.
			abortSwitch;
	}
	
	
	
	if (nextPacketDataLength > 0) {
		nextPacket = [[[self class] alloc] initWithBytes:nextPacketBytes length:nextPacketDataLength previousPacket:self];
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
	[nextPacket release];
	[data release];
	[fingerprint release];
	[keyID release];
	
	[super dealloc];
}


- (BOOL)isArmored:(const uint8_t)byte {
	if (!(byte & 0x80)) {
		return YES;
	}
	switch ((byte & 0x40) ? (byte & 0x3F) : ((byte & 0x3C) >> 2)) {
		case GPGPublicKeyEncryptedSessionKeyPacket:
		case GPGSignaturePacket:
		case GPGSymmetricEncryptedSessionKeyPacket:
		case GPGOnePassSignaturePacket:
		case GPGPublicKeyPacket:
		case GPGPublicSubkeyPacket:
		case GPGSecretKeyPacket:
		case GPGSecretSubkeyPacket:
		case GPGCompressedDataPacket:
		case GPGSymmetricEncryptedDataPacket:
		case GPGMarkerPacket:
		case GPGLiteralDataPacket:
		case GPGTrustPacket:
		case GPGUserIDPacket:
		case GPGUserAttributePacket:
		case GPGSymmetricEncryptedProtectedDataPacket:
		case GPGModificationDetectionCodePacket:
			return NO;
	}
	return YES;
}



@end
