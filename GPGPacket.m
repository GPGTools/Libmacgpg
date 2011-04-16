#import "GPGPacket.h"
#import "GPGGlobals.h"

#define COMMON_DIGEST_FOR_OPENSSL
#include <CommonCrypto/CommonDigest.h>


#define readUint8 (*((*((uint8_t**)&readPos))++))
#define readUint16 CFSwapInt16BigToHost(*((*((uint16_t**)&readPos))++))
#define readUint32 CFSwapInt32BigToHost(*((*((uint32_t**)&readPos))++))
#define readUint64 CFSwapInt64BigToHost(*((*((uint64_t**)&readPos))++))
#define abortInit [self release]; return nil;
#define abortSwitch type = 0; break;
#define canRead(x) if (readPos-bytes+(x) > dataLength) {abortInit;}



@implementation GPGPacket


@synthesize previousPacket;
@synthesize nextPacket;
@synthesize type;
@synthesize data;
@synthesize keyID;
@synthesize fingerprint;
@synthesize publicKeyAlgorithm;
@synthesize symetricAlgorithm;
@synthesize hashAlgorithm;
@synthesize signatureType;


- (id)initWithBytes:(const unsigned char *)bytes length:(NSUInteger)dataLength previousPacket:(GPGPacket *)prevPacket {
	if (!(self = [super init])) {
		return nil;
	}
	previousPacket = prevPacket;
	
	const unsigned char *readPos = bytes;
	canRead(1);
	
	
	BOOL newFormat = !!(bytes[0] & 0x40);
	unsigned int length;
	
	if (newFormat) {
		type = *readPos & 0x3F;
		readPos++;
		
		canRead(1);
		if (*readPos < 192) {
			length = readUint8;
		} else if (*readPos < 224) {
			canRead(2);
			length = ((readPos[0] - 192) << 8) + readPos[1] + 192;
			readPos += 2;
		} else if (*readPos == 255) {
			readPos++;
			canRead(4);
			length = readUint32;
		} else {
			abortInit;
		}
	} else {
		type = (*readPos & 0x3C) >> 2;
		if (type == 0) {
			abortInit;
		}
		char c = *readPos & 3;
		readPos++;
		switch (c) {
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
	
	const unsigned char *nextPacketBytes = readPos + length;
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
			const unsigned char *packetStart = readPos;
			canRead(6);
			if (readUint8 != 4) {
				abortSwitch;
			}
			readPos += 4;
			publicKeyAlgorithm = readUint8;
			
			
			unsigned char bytesForSHA1[length + 3];
			bytesForSHA1[0] = 0x99;
			uint16_t temp = length;
			bytesForSHA1[1] = ((uint8_t*)&temp)[1];
			bytesForSHA1[2] = ((uint8_t*)&temp)[0];
			memcpy(bytesForSHA1+3, packetStart, length);
			
			unsigned char fingerprintBytes[20];
			CC_SHA1(bytesForSHA1, length + 3, fingerprintBytes);
			fingerprint = [bytesToHexString(fingerprintBytes, 20) retain];
			keyID = [getKeyID(fingerprint) retain];
			
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
}

- (id)initWithData:(NSData *)theData {
	const unsigned char *bytes = [theData bytes];
	if (!(bytes[0] & 0x80)) {
		//TODO: Remove ASCII Armor
	}
	return [self initWithBytes:bytes length:[theData length] previousPacket:nil];
}

- (id)init {
	[self release];
	return nil;
}


+ (id)packetWithData:(NSData *)theData {
	return [[[self alloc] initWithData:theData] autorelease];
}


- (void)dealloc {
	[nextPacket release];
	[data release];
	[fingerprint release];
	[keyID release];
	
	[super dealloc];
}

@end
