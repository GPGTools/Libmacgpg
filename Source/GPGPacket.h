#import <Libmacgpg/GPGGlobals.h>

@interface GPGPacket : NSObject {
	GPGPacket *previousPacket;
	GPGPacket *nextPacket;

	int type;
	NSData *data;
	NSString *keyID;
	NSString *fingerprint;
	uint8_t publicKeyAlgorithm;
	uint8_t symetricAlgorithm;
	uint8_t hashAlgorithm;
	uint8_t signatureType;
}

@property (readonly) GPGPacket *previousPacket;
@property (readonly) GPGPacket *nextPacket;

@property (readonly) int type;
@property (readonly) NSData *data;
@property (readonly) NSString *keyID;
@property (readonly) NSString *fingerprint;
@property (readonly) uint8_t publicKeyAlgorithm;
@property (readonly) uint8_t symetricAlgorithm;
@property (readonly) uint8_t hashAlgorithm;
@property (readonly) uint8_t signatureType;



- (id)initWithData:(NSData *)data;
+ (id)packetWithData:(NSData *)theData;

@end
