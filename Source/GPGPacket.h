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

#import <Libmacgpg/GPGGlobals.h>

@class GPGStream;


@interface GPGPacket : NSObject {
	GPGPacketType type;
	NSData *data;
	NSString *keyID;
	NSString *fingerprint;
	uint8_t publicKeyAlgorithm;
	uint8_t symetricAlgorithm;
	uint8_t hashAlgorithm;
	uint8_t signatureType;
	NSString *description;
	NSMutableArray *subpackets;
}

@property (nonatomic, readonly) GPGPacketType type;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSString *keyID;
@property (nonatomic, readonly) NSString *fingerprint;
@property (nonatomic, readonly) uint8_t publicKeyAlgorithm;
@property (nonatomic, readonly) uint8_t symetricAlgorithm;
@property (nonatomic, readonly) uint8_t hashAlgorithm;
@property (nonatomic, readonly) uint8_t signatureType;

@property (nonatomic, readonly) NSArray *subpackets; // At the moment a array of dicts. Can change at any time.



+ (id)packetsWithData:(NSData *)data;
+ (void)enumeratePacketsWithData:(NSData *)theData block:(void (^)(GPGPacket *packet, BOOL *stop))block;
+ (BOOL)isArmored:(const uint8_t)byte;
// if return nil, input stream is not armored; should be reset and used directly
+ (NSData *)unArmorFrom:(GPGStream *)input clearText:(NSData **)clearText;
+ (NSData *)unArmor:(NSData *)data;
+ (NSData *)unArmor:(NSData *)theData clearText:(NSData **)clearText;
+ (NSData *)repairPacketData:(NSData *)data;

long crc24(char *bytes, NSUInteger length);

@end
