#import "GPGGlobals.h"
#import "GPGTask.h"

@implementation NSData (GPGExtension)
- (NSString *)gpgString {
	NSString *retString;
	
	// Löschen aller ungültigen Zeichen, damit die umwandlung nach UTF-8 funktioniert.
	const uint8_t *inText = [self bytes];
	if (!inText) {
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
		
		retString = [[NSString alloc] initWithUTF8String:(char*)outText];
		
		free(outText);
	} else {
		retString = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	}
	
	
	if (retString == nil) {
		retString = [[NSString alloc] initWithData:self encoding:NSISOLatin1StringEncoding];
	}
	return [retString autorelease];
}
@end
@implementation NSString (GPGExtension)
- (NSData *)gpgData {
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSUInteger)UTF8Length {
	return [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}
@end
@implementation NSDate (GPGExtension)
+ (id)dateWithGPGString:(NSString *)string {
	if ([string integerValue] == 0) {
		return nil;
	} else if ([string characterAtIndex:8] == 'T') {
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

NSString *GPGTaskException = @"GPGTaskException";
NSString *GPGException = @"GPGException";
NSString *GPGKeysChangedNotification = @"GPGKeysChangedNotification";
NSString *GPGOptionsChangedNotification = @"GPGOptionsChangedNotification";


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

//Wandelt "\\t" -> "\t", "\\x3a" -> ":" usw.
NSString *unescapeString(NSString *string) {
	const char *escapedText = [string UTF8String];
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
							*(unescapedTextPos++) = byte;
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

NSString* getShortKeyID(NSString *keyID) {
	return [keyID substringFromIndex:[keyID length] - 8];
}
NSString* getKeyID(NSString *fingerprint) {
	return [fingerprint substringFromIndex:[fingerprint length] - 16];
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

NSException* gpgTaskException(NSString *name, NSString *reason, int errorCode, GPGTask *gpgTask) {
	if (gpgTask.exitcode == GPGErrorCancelled) {
		errorCode = GPGErrorCancelled;
		reason = @"Operation cancelled!";
	}
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:gpgTask, @"gpgTask", [NSNumber numberWithInt:errorCode], @"errorCode", nil];
	return [NSException exceptionWithName:name reason:localizedString(reason) userInfo:userInfo];
}

NSException* gpgException(NSString *name, NSString *reason, int errorCode) {
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:errorCode], @"errorCode", nil];
	return [NSException exceptionWithName:name reason:localizedString(reason) userInfo:userInfo];
}

NSException* gpgExceptionWithUserInfo(NSString *name, NSString *reason, int errorCode, NSDictionary *userInfo) {
	NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
	[mutableUserInfo setObject:[NSNumber numberWithInt:errorCode] forKey:@"errorCode"];
	return [NSException exceptionWithName:name reason:localizedString(reason) userInfo:mutableUserInfo];
}






@implementation AsyncProxy
@synthesize realObject;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [realObject methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation setTarget:realObject];
	[NSThread detachNewThreadSelector:@selector(invoke) toTarget:anInvocation withObject:nil];
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









