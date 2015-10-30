#import "GPGUnArmor.h"
#import "GPGException.h"
#import "GPGMemoryStream.h"

static const NSUInteger cacheSize = 1000;
static const NSUInteger cacheReserve = 2; // Allow to read more bytes after the real buffer. See -getByte:

typedef enum {
	stateSearchBegin = 0,
	stateParseBegin,
	stateSearchBase64,
	stateSearchClearText,
	stateParseClearText,
	stateSearchSeperator,
	stateParseBase64,
	stateParseEnd,
	stateParseCRC,
	stateTrashEnd,
	stateError,
	stateEOF,
	stateFinish
} parsingState;

typedef enum {
	charTypeNormal = 0,
	charTypeWhitespace,
	charTypeNewline
} charaterType;


@interface GPGUnArmor ()
@property (nonatomic, readwrite, strong) NSError *error;
@property (nonatomic, readwrite, strong) NSData *clearText;
@property (nonatomic, readwrite, strong) NSData *data;
@end



@implementation GPGUnArmor
@synthesize error, clearText, data, eof;


#pragma Public methods

+ (GPGStream *)unArmor:(GPGStream *)stream clearText:(NSData **)clearText error:(NSError **)error {
	if (!stream.isArmored) {
		return stream;
	}
	
	GPGUnArmor *unArmor = [[self alloc] initWithGPGStream:stream];
	
	[unArmor decodeAll];
	
	if (clearText) {
		*clearText = unArmor.clearText;
	}
	if (error) {
		*error = unArmor.error;
	}
	GPGMemoryStream *output = [GPGMemoryStream memoryStreamForReading:unArmor.data];
	
	[unArmor release];
	
	return output;
}
+ (GPGStream *)unArmor:(GPGStream *)stream clearText:(NSData **)clearText {
	return [self unArmor:stream clearText:clearText error:nil];
}
+ (GPGStream *)unArmor:(GPGStream *)stream {
	return [self unArmor:stream clearText:nil error:nil];
}


- (NSData *)decodeNext {
	// The main decoding methode.
	// Mainly it invokes the different methods.
	
	self.error = nil;
	self.clearText = nil;
	self.data = nil;
	
	
	parsingState state = stateSearchBegin;
	BOOL running = YES;
	
	while (running) {
		switch (state) {
			case stateSearchBegin:
				state = [self searchBegin];
				break;
			case stateParseBegin:
				state = [self parseBegin];
				break;
			case stateSearchBase64:
				state = [self searchBase64];
				break;
			case stateSearchSeperator:
				state = [self searchSeperator];
				break;
			case stateParseBase64:
				state = [self parseBase64];
				break;
			case stateParseCRC:
				state = [self parseCRC];
				break;
			case stateSearchClearText:
				state = [self searchClearText];
				break;
			case stateParseClearText:
				state = [self parseClearText];
				break;
			case stateParseEnd:
				state = [self parseEnd];
				break;
			case stateTrashEnd:
				state = [self trashEnd];
				break;
				
			case stateError:
				running = NO;
				break;
			case stateEOF:
				eof = YES;
				running = NO;
				break;
			case stateFinish:
				running = NO;
				break;
		}
	}
	
	
	return self.data;
}

- (NSData *)decodeAll {
	
	NSMutableData *result = [NSMutableData data];
	NSData *clearTextResult = nil;
	
	
	while (!eof) {
		[self decodeNext];
		if (data.length > 0) {
			[result appendData:data];
		}
		if (clearText.length > 0) {
			clearTextResult = self.clearText;
		}
	}
	
	self.clearText = clearTextResult;
	self.data = result;
	
	return self.data;
}




#pragma Operation methods



- (parsingState)searchBegin {
	// Called at the beginning or after parseEnd if it has no data to decode.
	// Locate "-----BEGIN PGP " in the stream.
	
	const char beginMark[] = "BEGIN PGP ";
	NSInteger byte;
	NSInteger dashes = 0;
	NSInteger beginMarkIndex = 0;
	
	while ((byte = [self nextByte]) >= 0) {
		if (dashes < 5) {
			if (byte == '-') {
				dashes++;
			} else {
				dashes = 0;
			}
		} else {
			if (byte == '-' && beginMarkIndex == 0) {
				// Ignore
			} else if (byte == beginMark[beginMarkIndex]) {
				beginMarkIndex++;
				if (beginMark[beginMarkIndex] == 0) {
					return stateParseBegin;
				}
			} else {
				beginMarkIndex = 0;
				if (byte == '-') {
					dashes = 1;
				} else {
					dashes = 0;
				}
			}
		}
	}
	
	return stateEOF;
}


- (parsingState)parseBegin {
	// Called after searchBegin.
	// Parse the armor header line.
	// Succeess: searchClearText or searchBase64.
	// Fail: searchBegin.

	NSInteger byte;
	NSInteger dashes = 0;
	NSInteger headerLength = 0;
	
	
	UInt32 headerType = 0xFFFFFFFF;
	/*
	 Header types:
	 0x99FC7209 SIGNED MESSAGE
	 0x7607319A MESSAGE
	 0x72E896AA PUBLIC KEY BLOCK
	 0x15B5E051 SIGNATURE
	 0xAA272B8F ARMORED FILE
	 0xD9AC365B PRIVATE KEY BLOCK
	 0x4E6B6AC2 SECRET KEY BLOCK
	*/
	
	invalidCharInLine = NO;
	
	while ((byte = [self nextByte]) >= 0) {
		
		switch (byte) {
			case '-':
				dashes++;
				if (dashes == 5) {
					// Detect CR line-ending.
					if ([self getByte:0] == '\r' && [self getByte:1] != '\n') {
						crLineEnding = YES;
					} else {
						crLineEnding = NO;
					}
					
					if (headerType == 0x99FC7209) {
						// SIGNED MESSAGE: Clear-text follows.
						return stateSearchClearText;
					}
					return stateSearchBase64;
				}
				break;
			case 'A' ... 'G':
			case 'I':
			case 'K' ... 'P':
			case 'R' ... 'V':
			case 'Y':
			case ' ':
				headerLength++;
				if (dashes > 0 || headerLength > 17) {
					return stateSearchBegin;
				}
				headerType = crc32_tab[(headerType ^ byte) & 0xFF] ^ (headerType >> 8);
				break;
			default:
				// Invalid char.
				return stateSearchBegin;
				break;
		}
	}
	
	return stateEOF;
}


- (parsingState)searchClearText {
	// Called after parseBegin.
	// Wait for the clear-text.
	// Success: parseClearText.

	NSInteger byte;
	NSInteger newlineCount = 0;
	
	while ((byte = [self nextByte]) >= 0) {
		NSInteger type = [self characterType:byte];
		switch (type) {
			case charTypeWhitespace:
				break;
			case charTypeNewline:
				newlineCount++;
				if (newlineCount == 2) {
					// The clear-text comes after 2 new lines.
					return stateParseClearText;
				}
				break;
			default:
				newlineCount = 0;
				break;
		}
	}
	
	return stateEOF;
}


- (parsingState)parseClearText {
	// Called after searchClearText.
	// Parse the clear-text and store it in self.clearText.
	// Success: parseBegin.

	const char beginMark[] = "BEGIN PGP ";
	NSInteger byte;
	NSInteger dashes = -1;
	NSInteger beginMarkIndex = 0;
	NSMutableData *tempClearData = [[NSMutableData alloc] init];
	
	
	while ((byte = [self nextByte]) >= 0) {
		UInt8 theByte = (UInt8)byte;
		[tempClearData appendBytes:&theByte length:1];
		
		if (dashes == -1) {
			if ([self characterType:byte] == charTypeNewline) {
				dashes = 0;
			}
		} else if (dashes < 5) {
			if (byte == '-') {
				dashes++;
			} else if ([self characterType:byte] == charTypeNewline) {
				dashes = 0;
			} else {
				dashes = -1;
			}
		} else {
			if (byte == beginMark[beginMarkIndex]) {
				beginMarkIndex++;
				if (beginMark[beginMarkIndex] == 0) {
					NSUInteger length = tempClearData.length - 16;
					[tempClearData setLength:length];
					
					self.clearText = [self parseClearTextData:tempClearData];

					[tempClearData release];
					
					return stateParseBegin;
				}
			} else {
				beginMarkIndex = 0;
				if ([self characterType:byte] == charTypeNewline) {
					dashes = 0;
				} else {
					dashes = -1;
				}
			}
		}
	}
	
	[tempClearData release];

	return stateEOF;
}


- (parsingState)searchSeperator {
	// Called after searchBase64, parseBase64, parseCRC or parseEnd.
	// Locate the next seperator (one of \n \r \t \0 or " ").
	// Success: searchBase64.
	
	NSInteger byte;
	
	while ((byte = [self nextByte]) >= 0) {
		NSInteger type = [self characterType:byte];
		if (type >= 1) {
			return stateSearchBase64;
		}
	}
	
	return stateEOF;
}


- (parsingState)searchBase64 {
	// Called after parseBegin, searchSeperator, parseCRC or parseEnd.
	// Locate the first byte of the base64 encoded data.
	// Success: parseBase64.
	// Fail: searchSeperator or parseEnd.
	
	NSInteger byte;
	
	while ((byte = [self nextByte]) >= 0) {
		NSInteger type = [self characterType:byte];
		if (type >= 1) {
			continue;
		}

		switch (byte) {
			case 'g'...'z':
			case '0'...'9':
			case '+':
			case '/':
				// The first base64 char, can only be one of them,
				// because the first bit of a packet is 1.
				
				[base64Data setLength:0];
				[base64Data appendBytes:&byte length:1];
				return stateParseBase64;
			case '-':
				return stateParseEnd;
			default:
				return stateSearchSeperator;
		}
	}
	
	return stateEOF;
}


- (parsingState)parseBase64 {
	// Called after searchBase64.
	// Store the base64 encodeed data into base64Data.
	// Success: parseCRC or parseEnd.
	// Fail: searchSeperator.

	NSInteger byte;
	
	alternativeStart = 0;
	haveCRC = NO;
	BOOL isLineInvalid = invalidCharInLine;
	
	
	while ((byte = [self nextByte]) >= 0) {
		NSInteger type = [self characterType:byte];
		switch (type) {
			case charTypeWhitespace:
				continue;
			case charTypeNewline:
				if (alternativeStart == 0) {
					alternativeStart = base64Data.length;
					preferAlternative = isLineInvalid;
					isLineInvalid = NO;
				}
				continue;
		}

		switch (byte) {
			case 'a'...'z':
			case 'A'...'Z':
			case '0'...'9':
			case '+':
			case '/':
				[base64Data appendBytes:&byte length:1];
				break;
			case '-':
				return stateParseEnd;
			case '=':
				return stateParseCRC;
			default:
				return stateSearchSeperator;
		}
		
	}
	
	return stateEOF;
}


- (parsingState)parseCRC {
	// Called after parseBase64.
	// Store the base64 encoded crc24 into crcBytes.
	// Success: parseEnd.
	// Fail: searchSeperator or searchBase64.
	
	NSInteger byte;
	UInt8 lastByte = '=';
	
	NSInteger crcLength = -1;
	equalsAdded = 0;
	
	
	while ((byte = [self nextByte]) >= 0) {
		if (crcLength == -1) {
			if ([self characterType:byte] == charTypeNormal) {
				switch (byte) {
					case '=':
						equalsAdded++;
						if (equalsAdded == 2) {
							crcLength = 0;
						}
						[base64Data appendBytes:"=" length:1];
						break;
					case 'a'...'z':
					case 'A'...'Z':
					case '0'...'9':
					case '+':
					case '/':
						if (lastByte != '=') {
							return stateSearchSeperator;
						}
						crcBytes[0] = (UInt8)byte;
						crcLength = 1;
						break;
					case '-':
						equalsAdded++;
						[base64Data appendBytes:"=" length:1];
						return stateParseEnd;
					default:
						return stateSearchSeperator;
						break;
				}
			}
			lastByte = (UInt8)byte;
		} else if (crcLength < 4) {
			if ([self characterType:byte] >= 1) {
				return stateSearchBase64;
			}
			switch (byte) {
				case 'a'...'z':
				case 'A'...'Z':
				case '0'...'9':
				case '+':
				case '/':
					crcBytes[crcLength] = (UInt8)byte;
					crcLength++;
					break;
				default:
					return stateSearchSeperator;
					break;
			}
			lastByte = (UInt8)byte;
		} else if ([self characterType:byte] == charTypeNormal) {
			switch (byte) {
				case '-':
					if (crcLength == 4) {
						haveCRC = YES;
					} else {
						NSLog(@"unArmor: 'CRC malformed'");
						self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorChecksumError userInfo:nil];
					}
					return stateParseEnd;
				default:
					return stateSearchSeperator;
			}
		}
	}
	
	return stateEOF;
}


- (parsingState)parseEnd {
	// Called after searchBase64, parseBase64 or parseCRC.
	// Locate the end of the armored data.
	// Decode the base64 data and check the crc.
	// Store the decoded data in self.data.
	// Success: trashEnd.
	// Fail: searchSeperator, searchBase64, searchBegin.

	const char endMark[] = "----END PGP ";
	NSInteger byte;
	NSInteger endMarkIndex = 0;
	BOOL found = NO;
	
	
	while ((byte = [self nextByte]) >= 0) {
		if (byte == endMark[endMarkIndex]) {
			endMarkIndex++;
			if (endMark[endMarkIndex] == 0) {
				found = YES;
				break;
			}
		} else {
			haveCRC = NO;
			endMarkIndex = 0;
			if ([self characterType:byte] == charTypeNormal) {
				return stateSearchSeperator;
			} else {
				return stateSearchBase64;
			}
		}
	}
	if (!found) {
		return stateEOF;
	}


	UInt32 crc;
	if (haveCRC) {
		NSData *decodedCRC = nil;
		
		decodedCRC = [[NSData dataWithBytes:crcBytes length:4] base64DecodedData];
		
		if (decodedCRC.length == 3) {
			const uint8_t *crcBuffer = decodedCRC.bytes;
			
			// crc array to integer.
			crc = (crcBuffer[0] << 16) + (crcBuffer[1] << 8) + crcBuffer[2];
		} else {
			haveCRC = NO;
			// Decoded crc is malformed.
			NSLog(@"unArmor: 'CRC decoding failed'");
			self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorChecksumError userInfo:nil];
		}
	}
	
	
	NSData *preferedData = nil, *secondData = nil;
	
	if (alternativeStart && base64Data.length % 4 == 0 && (base64Data.length - alternativeStart) % 4 != 0) {
		preferAlternative = NO;
	}
	
	[base64Data appendBytes:"==" length:2 - equalsAdded];
	
	if (alternativeStart) {
		NSUInteger newLength = (base64Data.length - alternativeStart) & ~3;
		NSData *alternativeData = [base64Data subdataWithRange:NSMakeRange(alternativeStart, newLength)];
		
		if (preferAlternative) {
			preferedData = alternativeData;
		} else {
			secondData = alternativeData;
		}
	}
	
	[base64Data setLength:base64Data.length & ~3];
	
	
	if (preferedData) {
		secondData = base64Data;
	} else {
		preferedData = base64Data;
	}
	
	
	
	NSData *result = nil;
	if ([self isDataBase64EncodedPGP:preferedData]) {
		result = [preferedData base64DecodedData];
	}
	NSData *alternativeResult = result;
	
	if (haveCRC && result) {
		// Calculate crc of the decoded base64 data.
		UInt32 dataCRC = result.crc24;
		
		if (crc != dataCRC) {
			result = nil;
		}
	}
	
	if (!result) {
		if ([self isDataBase64EncodedPGP:secondData]) {
			result = [secondData base64DecodedData];
		}
		if (!result) {
			NSLog(@"unArmor: 'No Data'");
			self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorNoData userInfo:nil];
			return stateSearchBegin;
		}
		
		if (haveCRC) {
			// Calculate crc of the decoded base64 data.
			UInt32 dataCRC = result.crc24;
			
			if (crc != dataCRC) {
				if (alternativeResult) {
					result = alternativeResult;
				}
				
				NSLog(@"unArmor: 'CRC Error'");
				self.error = [NSError errorWithDomain:LibmacgpgErrorDomain code:GPGErrorChecksumError userInfo:nil];
			}
		}
	}
	
	self.data = result;
	
	return stateTrashEnd;
}


- (parsingState)trashEnd {
	// Called after parseEnd.
	// Read the stream to the end of the armor wrapping.
	// Success: stateFinish.

	NSInteger byte;
	NSInteger endMarkIndex = 0;
	NSInteger dashes = 0;
	
	while ((byte = [self nextByte]) >= 0) {
		endMarkIndex++;
		if (byte == '-') {
			dashes++;
		}
		if (endMarkIndex == 22 || dashes == 5) {
			[stream seekToOffset:streamOffset];
			cacheIndex = cacheSize;
			return stateFinish;
		}
	}
	
	return stateEOF;
}



#pragma Helper

static UInt32 crc32_tab[] = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
	0xe963a535, 0x9e6495a3,	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
	0xf3b97148, 0x84be41de,	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
	0xfa0f3d63, 0x8d080df5,	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
	0xdbbbc9d6, 0xacbcf940,	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
	0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
	0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
	0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
	0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
	0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
	0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
	0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
	0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
	0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
	0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
	0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
	0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
	0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
	0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
	0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
	0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
	0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};


- (NSData *)parseClearTextData:(NSData *)theData {
	NSInteger length = theData.length;
	const char *bytes = theData.bytes;
	
	
	NSMutableData *result = [NSMutableData dataWithCapacity:length];
	if (!result) {
		NSLog(@"parseClearText: dataWithCapacity failed!");
		return nil;
	}
	
	
	NSData *newLine = [NSData dataWithBytesNoCopy:"\n" length:1 freeWhenDone:NO];
	NSRange range = NSMakeRange(0, length);
	
	
	while (range.location < length) {
		NSRange foundRange = [theData rangeOfData:newLine options:0 range:range];
		if (foundRange.length == 0) {
			// No newline found. So this is the last line.
			foundRange.location = length;
		}
		
		// Length of this line.
		range.length = foundRange.location - range.location;
		
		// Remove leading "- ".
		if (range.length >= 2) {
			if (bytes[range.location] == '-' && bytes[range.location + 1] == ' ' ) {
				range.location += 2;
				range.length -= 2;
			}
		}
		
		// Remove trailing unprintable characters.
		BOOL stop = NO;
		while (range.length > 0 && stop == NO) {
			switch (bytes[range.location + range.length - 1]) {
				case 0:
				case '\t':
				case '\r':
				case ' ':
					range.length--;
					break;
				default:
					stop = YES;
					break;
			}
		}
		
		// Append the line to the result data.
		[result appendBytes:bytes + range.location length:range.length];
		
		if (foundRange.location < length) {
			// This isn't the last line. Append CRLF.
			[result appendBytes:"\r\n" length:2];
		}
		
		// Calculate the range of the remaining data.
		range.location = foundRange.location + 1;
		range.length = length - range.location;
	}
	
	return result;
}


- (BOOL)isDataBase64EncodedPGP:(NSData *)theData {
	if (theData.length < 8) {
		return NO;
	}
	NSData *decoded = [[theData subdataWithRange:NSMakeRange(0, 8)] base64DecodedData];
	if (decoded.length != 6) {
		return NO;
	}
	const UInt8 *bytes = decoded.bytes;
	
	if ((bytes[0] & 0x80) == 0) {
		return NO;
	}
	
	NSUInteger length;
	UInt8 tag;
	
	if (bytes[0] & 0x40) {
		// New Format
		tag = bytes[0] & 0x3F;
		
		if (bytes[1] < 192) {
			length = bytes[1] + 2;
		} else if (bytes[1] < 224) {
			length = ((bytes[1] - 192) << 8) + bytes[2] + 192 + 3;
		} else if (bytes[1] < 255) {
			length = 1 << (bytes[1] & 0x1F);
			if (length < 512) {
				return NO;
			}
			switch (tag) {
				case 8:
				case 9:
				case 11:
				case 18:
					break;
				default:
					return NO;
			}
			length += 2;
		} else {
			length = (bytes[2] << 24) + (bytes[3] << 16) + (bytes[4] << 8) + bytes[5] + 6;
		}
	} else {
		// Old Format
		
		tag = (bytes[0] & 0x3C) >> 2;
		
		
		switch (bytes[0] & 3) {
			case 0:
				length = bytes[1] + 2;
				break;
			case 1:
				length = (bytes[1] << 8) + bytes[2] + 3;
				break;
			case 2:
				length = (bytes[1] << 24) + (bytes[2] << 16) + (bytes[3] << 8) + bytes[4] + 5;
				break;
			case 3:
				// Indeterminate length.
				length = 1;
				break;
			default:
				return NO;
		}
	}
	
	if (theData.length < length) {
		return NO;
	}
	
	switch (tag) {
		case 1 ... 14:
		case 17 ... 19:
			break;
		default:
			return NO;
	}
	
	return YES;
}


- (charaterType)characterType:(NSInteger)byte {
	
	switch (byte) {
		case '\r':
			if (crLineEnding) {
				return charTypeNewline;
			} else {
				return charTypeWhitespace;
			}
		case ' ':
		case '\t':
		case 0:
			return charTypeWhitespace;
		case '\n':
			return charTypeNewline;
		case 0xE2: { // Possible an unicode separator.
			byte = [self getByte:0];
			if (byte != 0x80) {
				return charTypeNormal; // Not an separator;
			}
			
			byte = [self getByte:1];
			if (byte != 0xA8 && byte != 0xA9) {
				return charTypeNormal; // Not an separator;
			}
			
			[self nextByte]; // Consume the whole multi-byte caracter.
			[self nextByte];
			
			return charTypeNewline;
		}
		default:
			return charTypeNormal;
	}

}


- (NSInteger)nextByte {
	if (cacheIndex >= cacheSize) {
		NSData *tempData = [stream readDataOfLength:cacheSize];
		NSUInteger tempDataLength = tempData.length;
		
		if (cacheIndex == NSUIntegerMax) {
			cacheIndex = 2;
		} else {
			[cacheData replaceBytesInRange:NSMakeRange(0, cacheReserve) withBytes:cacheBytes+cacheSize];
			cacheIndex = 0;
		}
		[cacheData replaceBytesInRange:NSMakeRange(cacheReserve, tempDataLength) withBytes:tempData.bytes];
		
		if (tempDataLength < cacheSize) {
			cacheEnd = tempDataLength;
		}
	}
	if (cacheIndex == cacheEnd) {
		return -1;
	}
	
	UInt8 byte = cacheBytes[cacheIndex];
	cacheIndex++;
	streamOffset++;
	
	//TODO: Handle Unicode line seperators!
	switch (byte) {
		case '\n':
			invalidCharInLine = NO;
			break;
		case '\r':
		case ' ':
		case '\t':
		case 0:
		case 'a'...'z':
		case 'A'...'Z':
		case '0'...'9':
		case '+':
		case '/':
			break;
		default:
			invalidCharInLine = YES;
			break;
	}
	
	
	return byte;
}

- (NSInteger)getByte:(NSUInteger)offset {
	NSAssert(offset < cacheReserve, @"offset greater than cacheReserve!");

	NSUInteger index = cacheIndex + offset;
	if (index >= cacheEnd) {
		return -1;
	}
	
	UInt8 byte = cacheBytes[index];
	return byte;
}



#pragma init, dealloc, etc.

+ (instancetype)unArmorWithGPGStream:(GPGStream *)theStream {
	return [[[self alloc] initWithGPGStream:theStream] autorelease];
}

- (instancetype)initWithGPGStream:(GPGStream *)theStream {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	stream = [theStream retain];
	streamOffset = stream.offset;
	cacheEnd = NSUIntegerMax;
	cacheIndex = NSUIntegerMax;
	base64Data = [[NSMutableData alloc] init];
	cacheData = [[NSMutableData alloc] initWithLength:cacheSize + cacheReserve];
	cacheBytes = cacheData.mutableBytes;
	
	return self;
}

- (void)dealloc {
	[stream release];
	[base64Data release];
	[cacheData release];
	self.data = nil;
	self.clearText = nil;
	self.error = nil;
	[super dealloc];
}

@end


static BOOL isArmoredByte(UInt8 byte) {
	if (!(byte & 0x80)) {
		return YES;
	}
	UInt8 tag = (byte & 0x40) ? (byte & 0x3F) : ((byte & 0x3C) >> 2);
	switch (tag) {
		case 1 ... 14:
		case 17 ... 19:
			return NO;
	}
	return YES;
}


@implementation GPGStream (IsArmoredExtension)
- (BOOL)isArmored {
	UInt8 byte = [self peekByte];
	return isArmoredByte(byte);
}
@end
@implementation NSData (IsArmoredExtension)
- (BOOL)isArmored {
	if (self.length == 0) {
		return NO;
	}
	UInt8 byte = ((UInt8 *)self.bytes)[0];
	return isArmoredByte(byte);
}
@end




