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

#import "GPGTransformer.h"
#import "GPGGlobals.h"

#define maybeLocalize(key) (!_keepUnlocalized ? localizedLibmacgpgString(key) : key)

@implementation GPGKeyAlgorithmNameTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return [self transformedIntegerValue:[value integerValue]];
}
- (id)transformedIntegerValue:(NSInteger)value {
	switch (value) {
		case GPG_RSAAlgorithm:
			return maybeLocalize(@"GPG_RSAAlgorithm");
		case GPG_RSAEncryptOnlyAlgorithm:
			return maybeLocalize(@"GPG_RSAEncryptOnlyAlgorithm");
		case GPG_RSASignOnlyAlgorithm:
			return maybeLocalize(@"GPG_RSASignOnlyAlgorithm");
		case GPG_ElgamalEncryptOnlyAlgorithm:
			return maybeLocalize(@"GPG_ElgamalEncryptOnlyAlgorithm");
		case GPG_DSAAlgorithm:
			return maybeLocalize(@"GPG_DSAAlgorithm");
		case GPG_EllipticCurveAlgorithm:
			return maybeLocalize(@"GPG_EllipticCurveAlgorithm");
		case GPG_ECDSAAlgorithm:
			return maybeLocalize(@"GPG_ECDSAAlgorithm");
		case GPG_ElgamalAlgorithm:
			return maybeLocalize(@"GPG_ElgamalAlgorithm");
		case GPG_DiffieHellmanAlgorithm:
			return maybeLocalize(@"GPG_DiffieHellmanAlgorithm");
		case 0:
			return @"";
		default:
			return [NSString stringWithFormat:maybeLocalize(@"Algorithm_%i"), value];
	}
}

@end

@implementation GPGValidityDescriptionTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSMutableArray *strings = [NSMutableArray array];
	NSInteger intValue = [value integerValue];
	
	switch (intValue & 7) {
		case 2:
			[strings addObject:maybeLocalize(@"?")]; //Was bedeutet 2?
			break;
		case 3:
			[strings addObject:maybeLocalize(@"Marginal")];
			break;
		case 4:
			[strings addObject:maybeLocalize(@"Full")];
			break;
		case 5:
			[strings addObject:maybeLocalize(@"Ultimate")];
			break;
		default:
			if (intValue < GPGValidityInvalid) {
				[strings addObject:maybeLocalize(@"Unknown")];
			}
			break;
	}
	
	if (intValue & GPGValidityInvalid) {
		[strings addObject:maybeLocalize(@"Invalid")];
	}
	if (intValue & GPGValidityRevoked) {
		[strings addObject:maybeLocalize(@"Revoked")];
	}
	if (intValue & GPGValidityExpired) {
		[strings addObject:maybeLocalize(@"Expired")];
	}
	if (intValue & GPGValidityDisabled) {
		[strings addObject:maybeLocalize(@"Disabled")];
	}
	
	return [strings componentsJoinedByString:@", "];
}

@end

@implementation GPGFingerprintTransformer
@synthesize keepUnlocalized = _keepUnlocalized;

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSString *fingerprint = [value description];
	NSUInteger length = [fingerprint lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	const char *original = [fingerprint UTF8String];
	char *format;
	
	switch (length) {
		case 40:
			format = "XXXX XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX XXXX";
			break;
		case 32:
			format = "XXXX XXXX XXXX XXXX  XXXX XXXX XXXX XXXX";
			break;
		case 0:
			return @"";
		default:
			return fingerprint;
	}
	
	NSUInteger formatLength = strlen(format);
	NSMutableData *buffer = [NSMutableData dataWithLength:formatLength];
	char *bytes = [buffer mutableBytes];
	NSUInteger i1 = 0, i2 = 0;
	
	for (; i1 < formatLength; i1++) {
		char byte = 0;
		switch (format[i1]) {
			case ' ':
				byte = ' ';
				break;
			default:
				byte = original[i2++];
				break;
		}
		bytes[i1] = byte;
	}
	
	return [[[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding] autorelease];
}

@end




@implementation SplitFormatter
@synthesize blockSize;

- (id)init {
	if (self = [super init]) {
		blockSize = 4;
	}
	return self;
}

- (NSString *)stringForObjectValue:(id)obj {
	NSString *fingerprint = [obj description];
	NSUInteger length = [fingerprint length];
	if (length == 0) {
		return @"";
	}
	if (blockSize == 0) {
		return fingerprint;
	}
	
	NSMutableString *formattedFingerprint = [NSMutableString stringWithCapacity:length + (length - 1) / blockSize];
	
	NSRange range;
	range.location = 0;
	range.length = blockSize;
	
	
	for (; range.location + blockSize < length; range.location += blockSize) {
		[formattedFingerprint appendFormat:@"%@ ", [fingerprint substringWithRange:range]];
	}
	range.length = length - range.location;
	[formattedFingerprint appendString:[fingerprint substringWithRange:range]];
	
	return formattedFingerprint;
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error {
	*obj = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
	return YES;
}
- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	return YES;
}

@end
