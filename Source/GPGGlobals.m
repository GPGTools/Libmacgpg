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

#import "GPGGlobals.h"
#import "GPGTask.h"
#import "GPGKey.h"


NSString *localizedLibmacgpgString(NSString *key) {
	static NSBundle *bundle = nil, *englishBundle = nil;
	if (!bundle) {
		bundle = [[NSBundle bundleWithIdentifier:@"org.gpgtools.Libmacgpg"] retain];
		englishBundle = [[NSBundle bundleWithPath:[bundle pathForResource:@"en" ofType:@"lproj"]] retain];
	}

	NSString *notFoundValue = @"~#*?*#~";
	NSString *localized = [bundle localizedStringForKey:key value:notFoundValue table:nil];
	if (localized == notFoundValue) {
		localized = [englishBundle localizedStringForKey:key value:nil table:nil];
	}
	
	return localized;
}

@implementation NSData (GPGExtension)
- (NSString *)gpgString {
	NSString *retString;
	
	if ([self length] == 0) {
		GPGDebugLog(@"Used Encoding: Zero length");
		return @"";
	}

	retString = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	if (retString) {
		GPGDebugLog(@"Used Encoding: UTF-8.");
		return [retString autorelease];
	}
	
	// Löschen aller ungültigen Zeichen, damit die umwandlung nach UTF-8 funktioniert.
	const uint8_t *inText = [self bytes];
	if (!inText) {
		GPGDebugLog(@"Used Encoding: nil");
		return nil;
	}
	
	NSUInteger i = 0, c = [self length];
	
	uint8_t *outText = malloc(c + 1);
	if (outText) {
		uint8_t *outPos = outText;
		const uint8_t *startChar = nil;
		int multiByte = 0;
		
		for (; i < c; i++) {
			if (multiByte && (*inText & 0xC0) == 0x80) { // Fortsetzung eines Mehrbytezeichen
				multiByte--;
				if (multiByte == 0) {
					while (startChar <= inText) {
						*(outPos++) = *(startChar++);
					}
				}
			} else if ((*inText & 0x80) == 0) { // Normales ASCII Zeichen.
				*(outPos++) = *inText;
				multiByte = 0;
			} else if ((*inText & 0xC0) == 0xC0) { // Beginn eines Mehrbytezeichen.
				if (multiByte) {
					*(outPos++) = '?';
				}
				if (*inText <= 0xDF && *inText >= 0xC2) {
					multiByte = 1;
					startChar = inText;
				} else if (*inText <= 0xEF && *inText >= 0xE0) {
					multiByte = 2;
					startChar = inText;
				} else if (*inText <= 0xF4 && *inText >= 0xF0) {
					multiByte = 3;
					startChar = inText;
				} else {
					*(outPos++) = '?';
					multiByte = 0;
				}
			} else {
				*(outPos++) = '?';
			}
			
			inText++;
		}
		*outPos = 0;
		
		retString = [[[NSString alloc] initWithUTF8String:(char*)outText] autorelease];
		
		free(outText);
		if (retString) {
			GPGDebugLog(@"Used Encoding: Cleaned UTF-8.");
			return retString;
		}
	}
	// Ende der Säuberung.

	
	
	int encodings[3] = {NSISOLatin1StringEncoding, NSISOLatin2StringEncoding, NSASCIIStringEncoding};
	for(i = 0; i < 3; i++) {
		retString = [[[NSString alloc] initWithData:self encoding:encodings[i]] autorelease];
		if([retString length] > 0) {
			GPGDebugLog(@"Used Encoding: %i", encodings[i]);
			return retString;
		}
	}
	
	if (retString == nil) {
		@throw [NSException exceptionWithName:@"GPGUnknownStringEncodingException"
									   reason:@"It was not possible to recognize the string encoding." userInfo:nil];
	}
	
	return retString;
}

- (NSArray *)gpgLines {
	// Split the data object into an array of string (the lines).
	
	if ([self length] == 0) {
		return @[];
	}
	
	// Encode to an NSString using UTF8.
	NSString *string = [[[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding] autorelease];
	if (string) {
		// Split the string into lines, and return it.
		return [string componentsSeparatedByString:@"\n"];
	}
	
	// Not a pure UTF8 string. We need to parse it manually.
	// Step byte by byte through the data to find line endings.
	// Convert every line to an NSString, this allows a different encoding for every line.
	
	NSMutableArray *lines = [NSMutableArray array];
	
	const uint8_t *bytes = [self bytes];
	NSUInteger i = 0, c = [self length];
	NSUInteger start = 0;
	NSUInteger add = 0;
	
	for (; i < c; i++) {
		switch (bytes[i]) {
			case '\r':
				if (i+1 < c && bytes[i+1] == '\n') {
					add = 1;
				}
				// No break!
			case '\n': {
				if (i-start > 0) {
					NSString *line;
					
					// Try some encodings.
					int encodings[3] = {NSUTF8StringEncoding, NSISOLatin1StringEncoding, NSWindowsCP1252StringEncoding};
					for (int j = 0; j < 3; j++) {
						line = [[[NSString alloc] initWithBytes:bytes+start length:i-start encoding:encodings[j]] autorelease];
						
						if (line.length > 0) {
							GPGDebugLog(@"Used Encoding: %i", encodings[j]);
							break;
						}
					}
					
					if (line.length == 0) {
						// Our last chance, use gpgString.
						NSData *subData = [[NSData alloc] initWithBytesNoCopy:(void *)(bytes+start) length:i-start freeWhenDone:NO];
						line = [subData gpgString];
						[subData release];
					}
					
					if (line) {
						[lines addObject:line];
					} else {
						[lines addObject:@""];
					}
				} else {
					[lines addObject:@""];
				}
				
				i += add;
				start = i + 1;
				break;
			}
		}
	}
	return [lines copy];
}

@end

@implementation NSString (GPGExtension)
- (NSData *)UTF8Data {
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSUInteger)UTF8Length {
	return [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)shortKeyID {
	return [self substringFromIndex:[self length] - 8];
}
- (NSString *)keyID {
	return [self substringFromIndex:[self length] - 16];
}
- (NSString *)unescapedString {
	//Wandelt "\\t" -> "\t", "\\x3a" -> ":" usw.
	
	const char *escapedText = [self UTF8String];
	char *unescapedText = malloc(strlen(escapedText) + 1);
	if (!unescapedText) {
		return nil;
	}
	char *unescapedTextPos = unescapedText;
	
	while (*escapedText) {
		if (*escapedText == '\\') {
			escapedText++;
			switch (*escapedText) {
#define DECODE_ONE(match, result) \
case match: \
escapedText++; \
*(unescapedTextPos++) = result; \
break;
					
					DECODE_ONE ('\'', '\'');
					DECODE_ONE ('\"', '\"');
					DECODE_ONE ('\?', '\?');
					DECODE_ONE ('\\', '\\');
					DECODE_ONE ('a', '\a');
					DECODE_ONE ('b', '\b');
					DECODE_ONE ('f', '\f');
					DECODE_ONE ('n', '\n');
					DECODE_ONE ('r', '\r');
					DECODE_ONE ('t', '\t');
					DECODE_ONE ('v', '\v');
					
				case 'x': {
					escapedText++;
					int byte = hexToByte(escapedText);
					if (byte == -1) {
						*(unescapedTextPos++) = '\\';
						*(unescapedTextPos++) = 'x';
					} else {
						if (byte == 0) {
							*(unescapedTextPos++) = '\\';
							*(unescapedTextPos++) = '0';
						} else {
							*(unescapedTextPos++) = (char)byte;
						}
						escapedText += 2;
					}
					break; }
				default:
					*(unescapedTextPos++) = '\\';
					*(unescapedTextPos++) = *(escapedText++);
					break;
			}
		} else {
			*(unescapedTextPos++) = *(escapedText++);
		}
	}
	*unescapedTextPos = 0;
	
	NSString *retString = [NSString stringWithUTF8String:unescapedText];
	free(unescapedText);
	return retString;
}
- (NSDictionary *)splittedUserIDDescription {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
	NSString *workText = self;
	NSUInteger textLength = [workText length];
	NSRange range;

	[dict setObject:workText forKey:@"userIDDescription"];

	if ([workText hasSuffix:@">"]) {
		range = [workText rangeOfString:@"<" options:NSBackwardsSearch];
		if (range.length > 0) {
			range.location += 1;
			range.length = textLength - range.location - 1;
			
			NSString *value = [workText substringWithRange:range];
			[dict setObject:value forKey:@"email"];
			
			if (range.location > 2) {
				workText = [workText substringToIndex:range.location - 2];
				textLength -= (range.length + 3);
			} else {
				workText = @"";
				textLength = 0;
			}
		}
	}
	if ([workText hasSuffix:@")"]) {
		range = [workText rangeOfString:@"(" options:NSBackwardsSearch];
		if (range.length > 0) {
			range.location += 1;
			range.length = textLength - range.location - 1;
			
			NSString *value = [workText substringWithRange:range];
			[dict setObject:value forKey:@"comment"];
			
			if (range.location > 2) {
				workText = [workText substringToIndex:range.location - 2];
				textLength -= (range.length + 3);
			} else {
				workText = @"";
				textLength = 0;
			}
		}
	}
	
	[dict setObject:workText forKey:@"name"];
	return dict;
}


@end

@implementation NSDate (GPGExtension)
+ (id)dateWithGPGString:(NSString *)string {
	if ([string integerValue] == 0) {
		return nil;
	} else if (string.length > 8 && [string characterAtIndex:8] == 'T') {
		NSString *year = [string substringWithRange:NSMakeRange(0, 4)];
		NSString *month = [string substringWithRange:NSMakeRange(4, 2)];
		NSString *day = [string substringWithRange:NSMakeRange(6, 2)];
		NSString *hour = [string substringWithRange:NSMakeRange(9, 2)];
		NSString *minute = [string substringWithRange:NSMakeRange(11, 2)];
		NSString *second = [string substringWithRange:NSMakeRange(13, 2)];
		
		return [NSDate dateWithString:[NSString stringWithFormat:@"%@-%@-%@ %@:%@:%@ +0000", year, month, day, hour, minute, second]];
	} else {
		return [self dateWithTimeIntervalSince1970:[string integerValue]];
	}
}
@end

@implementation NSArray (IndexInfo)
- (NSIndexSet *)indexesOfIdenticalObjects:(id <NSFastEnumeration>)objects {
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	for (id object in objects) {
		NSUInteger aIndex = [self indexOfObjectIdenticalTo:object];
		if (aIndex != NSNotFound) {
			[indexes addIndex:aIndex];
		}
	}
	return indexes;
}
@end

@implementation NSSet (GPGExtension)
- (NSSet *)usableGPGKeys {
	Class gpgKeyClass = [GPGKey class];
	return [self objectsPassingTest:^BOOL(id obj, BOOL *stop) {
		if ([obj isKindOfClass:gpgKeyClass] && ((GPGKey *)obj).validity < GPGValidityInvalid) {
			return YES;
		}
		return NO;
	}];
}
@end


int hexToByte (const char *text) {
	int retVal = 0;
	int i;
	
	for (i = 0; i < 2; i++) {
		if (*text >= '0' && *text <= '9') {
			retVal += *text - '0';
		} else if (*text >= 'A' && *text <= 'F') {
			retVal += 10 + *text - 'A';
		} else if (*text >= 'a' && *text <= 'f') {
			retVal += 10 + *text - 'a';
		} else {
			return -1;
		}
		
		if (i == 0) {
			retVal *= 16;
		}
		text++;
    }
	return retVal;
}
NSString* bytesToHexString(const uint8_t *bytes, NSUInteger length) {
	char table[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
	char hexString[length * 2 + 1];
	hexString[length * 2] = 0;
	
	for (int i = 0; i < length; i++) {
		hexString[i*2] = table[bytes[i] >> 4];
		hexString[i*2+1] = table[bytes[i] & 0xF];
	}
	return [NSString stringWithUTF8String:hexString];
}


NSSet *importedFingerprintsFromStatus(NSDictionary *statusDict) {
	NSMutableSet *fingerprints = [NSMutableSet set];
	NSArray *lines = [statusDict objectForKey:@"IMPORT_OK"];
	
	for (NSArray *line in lines) {
		NSString *fingerprint = [line objectAtIndex:1];
		[fingerprints addObject:fingerprint];
	}
	return [fingerprints count] ? fingerprints : nil;
}

void *lm_memmem(const void *big, size_t big_len, const void *little, size_t little_len) {
#if defined (__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7
	if (memmem != NULL) {
		return memmem(big, big_len, little, little_len);
	}
#endif
	if (little_len == 1) {
		return memchr(big, *(const unsigned char *)little, big_len);
	}
	const unsigned char *y = (const unsigned char *)big;
	const unsigned char *x = (const unsigned char *)little;
	size_t j, k, l;
	
	if (little_len > big_len)
		return NULL;
	
	if (x[0] == x[1]) {
		k = 2;
		l = 1;
	} else {
		k = 1;
		l = 2;
	}
	
	j = 0;
	while (j <= big_len-little_len) {
		if (x[1] != y[j+1]) {
			j += k;
		} else {
			if (!memcmp(x+2, y+j+2, little_len-2) && x[0] == y[j])
				return (void *)&y[j];
			j += l;
		}
	}
	
	return NULL;
}



@implementation AsyncProxy
@synthesize realObject;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [realObject methodSignatureForSelector:aSelector];
}
- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(invokeWithPool:)) {
		return YES;
	}
	return [super respondsToSelector:aSelector];
}
- (void)invokeWithPool:(NSInvocation *)anInvocation {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[anInvocation invoke];
	[pool drain];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
	[anInvocation retainArguments];
    [anInvocation setTarget:realObject];
	[NSThread detachNewThreadSelector:@selector(invokeWithPool:) toTarget:self withObject:anInvocation];
}
+ (id)proxyWithRealObject:(NSObject *)object {
	return [[[[self class] alloc] initWithRealObject:object] autorelease];
}
- (id)initWithRealObject:(NSObject *)object {
	realObject = object;
	return self;
}
- (id)init {
	return [self initWithRealObject:nil];
}
@end
