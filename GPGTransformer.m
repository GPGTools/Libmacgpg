#import "GPGTransformer.h"
#import "GPGGlobals.h"

@implementation GPGKeyAlgorithmNameTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	switch ([value integerValue]) {
		case GPG_RSAAlgorithm:
			return localizedLibmacgpgString(@"GPG_RSAAlgorithm");
		case GPG_RSAEncryptOnlyAlgorithm:
			return localizedLibmacgpgString(@"GPG_RSAEncryptOnlyAlgorithm");
		case GPG_RSASignOnlyAlgorithm:
			return localizedLibmacgpgString(@"GPG_RSASignOnlyAlgorithm");
		case GPG_ElgamalEncryptOnlyAlgorithm:
			return localizedLibmacgpgString(@"GPG_ElgamalEncryptOnlyAlgorithm");
		case GPG_DSAAlgorithm:
			return localizedLibmacgpgString(@"GPG_DSAAlgorithm");
		case GPG_EllipticCurveAlgorithm:
			return localizedLibmacgpgString(@"GPG_EllipticCurveAlgorithm");
		case GPG_ECDSAAlgorithm:
			return localizedLibmacgpgString(@"GPG_ECDSAAlgorithm");
		case GPG_ElgamalAlgorithm:
			return localizedLibmacgpgString(@"GPG_ElgamalAlgorithm");
		case GPG_DiffieHellmanAlgorithm:
			return localizedLibmacgpgString(@"GPG_DiffieHellmanAlgorithm");
		default:
			return @"";
	}
}

@end

@implementation GPGKeyStatusDescriptionTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSMutableString *statusText = [NSMutableString stringWithCapacity:2];
	NSInteger intValue = [value integerValue];
	
	switch (intValue & 7) {
		case 2:
			[statusText appendString:localizedLibmacgpgString(@"?")]; //Was bedeutet 2? 
			break;
		case 3:
			[statusText appendString:localizedLibmacgpgString(@"Marginal")];
			break;
		case 4:
			[statusText appendString:localizedLibmacgpgString(@"Full")];
			break;
		case 5:
			[statusText appendString:localizedLibmacgpgString(@"Ultimate")];
			break;
		default:
			[statusText appendString:localizedLibmacgpgString(@"Unknown")];
			break;
	}
	
	if (intValue & GPGKeyStatus_Invalid) {
		[statusText appendFormat:@", %@", localizedLibmacgpgString(@"Invalid")];
	}
	if (intValue & GPGKeyStatus_Revoked) {
		[statusText appendFormat:@", %@", localizedLibmacgpgString(@"Revoked")];
	}
	if (intValue & GPGKeyStatus_Expired) {
		[statusText appendFormat:@", %@", localizedLibmacgpgString(@"Expired")];
	}
	if (intValue & GPGKeyStatus_Disabled) {
		[statusText appendFormat:@", %@", localizedLibmacgpgString(@"Disabled")];
	}
	return [[statusText copy] autorelease];
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
	return NO;
}
- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**) newString errorDescription:(NSString**)error {
	return YES;
}

@end
