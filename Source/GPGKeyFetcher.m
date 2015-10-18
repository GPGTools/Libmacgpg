#import "GPGKeyFetcher.h"
#import "Libmacgpg.h"

@implementation GPGKeyFetcher


- (void)fetchKeyForMailAddress:(NSString *)mailAddress block:(void (^)(NSData *data, NSString *verifiedMail, NSError *error))block {
	mailAddress = [[mailAddress copy] autorelease]; // We need it immutable for NSCache.
	
	NSDictionary *chachedEntry = [cache objectForKey:mailAddress];
	if (chachedEntry) {
		block(chachedEntry[@"data"], chachedEntry[@"verifiedMail"], nil);
		return;
	}
	
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://keys.whiteout.io/%@", mailAddress]];
	NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:url cachePolicy:0 timeoutInterval:10] autorelease];
	
	
	NSOperationQueue *queue = [NSOperationQueue currentQueue];
	if (!queue) {
		queue = [NSOperationQueue mainQueue];
		if (!queue) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No operation queue" userInfo:nil];

		}
	}
	
	[NSURLConnection sendAsynchronousRequest:request
									   queue:queue
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
	{
		NSString *verifiedMail = nil;

		// A valid response contains at least 100 bytes of data and is armored.
		if (data.length > 100 && data.isArmored) {
			
			// Look if the key wasn't from the whiteout keyserver.
			NSData *newline = [NSData dataWithBytesNoCopy:"\n" length:1 freeWhenDone:NO];
			NSCharacterSet *nonWhitespaceSet = [[NSCharacterSet characterSetWithCharactersInString:@"\r\t "] invertedSet];
			NSRange searchRange = NSMakeRange(0, data.length);
			NSRange range;
			verifiedMail = mailAddress;
			
			while ((range = [data rangeOfData:newline options:0 range:searchRange]).length > 0) {
				NSRange lineRange = NSMakeRange(searchRange.location, range.location - searchRange.location);
				NSData *lineData = [data subdataWithRange:lineRange];
				NSString *line = lineData.gpgString;
				
				if (!line) {
					// Should never happen!
					verifiedMail = nil;
					break;
				}
				if ([line rangeOfCharacterFromSet:nonWhitespaceSet].length == 0) {
					// An empty line seperates the header from the base64.
					break;
				}
				if (line.length > 19 && [[line substringToIndex:19] isEqualToString:@"Comment: Hostname: "]) {
					// The key is from another keyserver. So the Mail-Address is not verified.
					verifiedMail = nil;
					break;
				}
				
				searchRange.location = range.location + 1;
				searchRange.length = data.length - searchRange.location;
			}
			
			// UnArmor the data.
			data = [[GPGUnArmor unArmor:[GPGMemoryStream memoryStreamForReading:data]] readAllData];
		} else {
			data = nil;
		}
		
		
		if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
			NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
			
			// Only cache if the server says the key was found or there is no key for this mail address.
			// Don't cache if there was a connectionError or something.
			if (statusCode == 200 || statusCode == 404) {
				NSDictionary *cacheEntry = [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", verifiedMail, @"verifiedMail", nil];
				[cache setObject:cacheEntry forKey:mailAddress];
				
				// Case insensitive cache.
				if (verifiedMail) {
					NSString *caseInsensitiveKey = [[mailAddress lowercaseString] stringByAppendingString:@"_insensitive"];
					[cache setObject:cacheEntry forKey:caseInsensitiveKey];
				}
			}
		}
		
		block(data, verifiedMail, connectionError);
	}];
	
}







- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}
	
	cache = [NSCache new];
	
	return self;
}

- (void)dealloc {
	[cache release];
	[super dealloc];
}


@end
