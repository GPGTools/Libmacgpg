//
//  GPGKeyserver.m
//  Libmacgpg
//
//  Created by Mento on 09.07.13.
//
//

#import "GPGKeyserver.h"
#import "GPGOptions.h"
#import "GPGException.h"

@interface GPGKeyserver ()
@property (retain, nonatomic) NSURLConnection *connection;
@property (retain, nonatomic) GPGException *exception;
@end


@implementation GPGKeyserver
@synthesize keyserver, connection, receivedData, userInfo, isRunning, lastOperation, finishedHandler, exception, timeout;


#pragma mark Public methods

- (void)getKey:(NSString *)keyID {
	[self start];
	lastOperation = _cmd;
	
	switch (keyID.length) {
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"KeyID with invalid length" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", nil]];
		case 8:
		case 16:
		case 32:
		case 40:
			break;
		case 10:
		case 18:
		case 34:
		case 42:
			keyID = [keyID substringFromIndex:2];
			break;
	}
	NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
	
	if ([keyID rangeOfCharacterFromSet:noHexCharSet].length > 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Invalid KeyID" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", nil]];
	}
	
	keyID = [@"0x" stringByAppendingString:keyID];
	
	NSString *query = [NSString stringWithFormat:@"/pks/lookup?op=get&options=mr&search=%@", keyID];
	
	[self sendRequestWithQuery:query postData:nil];
}

- (void)searchKey:(NSString *)pattern {
	[self start];
	lastOperation = _cmd;

	if (pattern.length == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No pattern given" userInfo:nil];
	}
	
	pattern = [pattern stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	NSString *query = [NSString stringWithFormat:@"/pks/lookup?op=index&options=mr&search=%@", pattern];
	
	[self sendRequestWithQuery:query postData:nil];
}

- (void)uploadKeys:(NSString *)armored {
	[self start];
	lastOperation = _cmd;

	if (armored.length == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No key given" userInfo:nil];
	}
	
	
	NSString *urlEncoded = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)armored, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
	NSString *postString = [NSString stringWithFormat:@"keytext=%@", urlEncoded];
	NSData *postData = [postString dataUsingEncoding:NSUTF8StringEncoding];
	
	[self sendRequestWithQuery:@"/pks/add" postData:postData];
}

- (void)cancel {
	if (!_cancelled) {
		_cancelled = YES;
		[connection cancel];
		self.connection = nil;
		[self failedWithException:[GPGException exceptionWithReason:localizedLibmacgpgString(@"Operation cancelled") errorCode:GPGErrorCancelled]];
	}
}







#pragma mark Internal methods

- (void)start {
	_cancelled = NO;
	isRunning = YES;
	receivedData.length = 0;
}

- (NSURL *)keyserverURLWithQuery:(NSString *)query error:(NSError **)error {
	NSURL *url = [NSURL URLWithString:self.keyserver];
	
	if (!url) {
		*error = [NSError errorWithDomain:GPGErrorDomain code:GPGErrorNoKeyserverURL userInfo:nil];
		return nil;
	}
	if (!url.scheme) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"hkp://%@", self.keyserver]];
		if (!url.scheme) {
			*error = [NSError errorWithDomain:GPGErrorDomain code:GPGErrorParseError userInfo:nil];
			return nil;
		}
	}
	
	
	NSString *auth = @"";
	if (url.user) {
		if (url.password) {
			auth = [url.user stringByAppendingFormat:@":%@@", url.password];
		} else {
			auth = [url.user stringByAppendingString:@"@"];
		}
	}
	
	id port = url.port;
	if (!port) {
		if ([url.scheme isEqualToString:@"http"]) {
			port = @"80";
		} else if ([url.scheme isEqualToString:@"https"]) {
			port = @"443";
		} else {
			port = @"11371";
		}
	}
	
	
	NSRange range = [query rangeOfString:@"?"];
	NSString *queryString = @"";
	NSString *pathString;
	if (range.location == NSNotFound) {
		pathString = query;
	} else {
		pathString = [query substringToIndex:range.location];
		if (range.location < query.length) {
			queryString = [query substringFromIndex:range.location + 1];
		}
	}
	
	
	
	NSString *path = url.path;
	if (!path) path = @"";
	path = [path stringByAppendingPathComponent:pathString];
	
	NSString *parameterString = url.parameterString ? [NSString stringWithFormat:@";%@", url.parameterString] : @"";
	
	
	query = url.query ? [NSString stringWithFormat:@"?%@&%@", url.query, queryString] : [NSString stringWithFormat:@"?%@", queryString];
	if (query.length == 1) {
		query = @"";
	}
	
	NSString *fragment = url.fragment ? [NSString stringWithFormat:@"#%@", url.fragment] : @"";
	
	
	NSString *urlString = [NSString stringWithFormat:@"http://%@%@:%@%@%@%@%@", auth, url.host, port, path, parameterString, query, fragment];
	
	return [NSURL URLWithString:urlString];
}

- (void)sendRequestWithQuery:(NSString *)query postData:(NSData *)postData {
	receivedData.length = 0;
	NSError *error = nil;
	NSURL *url = [self keyserverURLWithQuery:query error:&error];
	if (!url) {
		GPGErrorCode errorCode = GPGErrorKeyServerError;
		if (error) {
			errorCode = error.code;
		}
		[self failedWithException:[GPGException exceptionWithReason:@"keyserverURLWithQuery failed!" errorCode:errorCode]];
	}
		
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:0 timeoutInterval:self.timeout];
	if (!request) {
		[self failedWithException:[GPGException exceptionWithReason:@"NSURLRequest failed!" errorCode:GPGErrorKeyServerError]];
	}
	if (postData) {
		request.HTTPMethod = @"POST";
		request.HTTPBody = postData;
	}
	
	NSURLConnection *theConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[theConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[theConnection start];
	[request release];
	
	if (theConnection) {
		self.connection = theConnection;
		[theConnection release];
	} else {
		[self failedWithException:[GPGException exceptionWithReason:@"NSURLConnection failed!" errorCode:GPGErrorKeyServerError]];
	}
}

- (void)failedWithException:(NSException *)e {
	self.exception = e;
	
	if (finishedHandler) {
		finishedHandler(self);
	}
}



#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSInteger statusCode = response.statusCode;
		
		switch (statusCode) {
			case 200:
			case 404:
			case 500:
				break;
			default:
				self.exception = [GPGException exceptionWithReason:[NSString stringWithFormat:@"Server returned status code %li (%@)", (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]]
														  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:statusCode], @"statusCode", nil]
														 errorCode:GPGErrorKeyServerError gpgTask:nil];
				break;
		}
	}
	
	receivedData.length = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self failedWithException:[GPGException exceptionWithReason:error.localizedDescription userInfo:error.userInfo errorCode:GPGErrorKeyServerError gpgTask:nil]];
	self.connection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (finishedHandler) {
		finishedHandler(self);
	}
	
	self.connection = nil;
}



#pragma mark init and dealloc

- (id)initWithFinishedHandler:(gpg_ks_finishedHandler)handler {
	if (!(self = [super init])) {
		return nil;
	}
	
	self.finishedHandler = handler;
	self.keyserver = [[GPGOptions sharedOptions] keyserver];
	receivedData = [[NSMutableData alloc] init];
	self.timeout = 30;
	
	return self;
}

- (id)init {
	return [self initWithFinishedHandler:nil];
}

- (void)dealloc {
	self.keyserver = nil;
	self.connection = nil;
	self.userInfo = nil;
	[receivedData release];
	
	[super dealloc];
}



@end






