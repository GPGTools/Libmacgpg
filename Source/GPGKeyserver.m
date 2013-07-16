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
@end


@implementation GPGKeyserver
@synthesize keyserver, connection, receivedData, delegate, userInfo, isRunning;


#pragma mark Public methods

- (void)getKey:(NSString *)keyID {
	[self start];
	
	switch (keyID.length) {
		default:
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"KeyID with invalid length" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", nil]];
		case 8:
		case 16:
		case 32:
		case 40:
			keyID = [@"0x" stringByAppendingString:keyID];
			break;
		case 10:
		case 18:
		case 34:
		case 42:
			break;
	}
	NSCharacterSet *noHexCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] invertedSet];
	if ([keyID rangeOfCharacterFromSet:noHexCharSet].length > 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Invalid KeyID" userInfo:[NSDictionary dictionaryWithObjectsAndKeys:keyID, @"keyID", nil]];
	}
	
	NSString *query = [NSString stringWithFormat:@"op=get&options=mr&search=%@", keyID];
	
	[self sendRequestWithQuery:query];
}

- (void)searchKey:(NSString *)pattern {
	[self start];

	if (pattern.length == 0) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"No pattern given" userInfo:nil];
	}
	
	pattern = [pattern stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	NSString *query = [NSString stringWithFormat:@"op=index&options=mr&search=%@", pattern];
	
	[self sendRequestWithQuery:query];
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
}

- (NSURL *)keyserverURLWithQuery:(NSString *)query {
	NSURL *url = [NSURL URLWithString:self.keyserver];
	
	if (!url) {
		return nil;
	}
	if (!url.scheme) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"hkp://%@", self.keyserver]];
		if (!url.scheme) {
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
		} else {
			port = @"11371";
		}
	}
	
	NSString *path = url.path;
	if (!path) path = @"";
	path = [path stringByAppendingPathComponent:@"/pks/lookup"];
	
	NSString *parameterString = url.parameterString ? [NSString stringWithFormat:@";%@", url.parameterString] : @"";
	
	NSString *urlQuery = url.query ? [url.query stringByAppendingString:@"&"] : @"";
	query = [NSString stringWithFormat:@"?%@%@", urlQuery, query];
	
	NSString *fragment = url.fragment ? [NSString stringWithFormat:@"#%@", url.fragment] : @"";
	
	
	
	NSString *urlString = [NSString stringWithFormat:@"http://%@%@:%@%@%@%@%@", auth, url.host, port, path, parameterString, query, fragment];
	
	return [NSURL URLWithString:urlString];
}

- (void)sendRequestWithQuery:(NSString *)query {
	receivedData.length = 0;
	NSURL *url = [self keyserverURLWithQuery:query];
		
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url  cachePolicy:0 timeoutInterval:60.0];
	NSURLConnection *theConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	[request release];
	
	if (theConnection) {
		self.connection = theConnection;
		[theConnection release];
	} else {
		[self failedWithException:[GPGException exceptionWithReason:@"NSURLConnection failed!" errorCode:GPGErrorKeyServerError]];
	}
}

- (void)failedWithException:(NSException *)exception {
	[self.delegate keyserver:self didFailWithException:exception];
}



#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	//TODO: response auswerten.	
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
	[self.delegate keyserverDidFinishLoading:self];
	self.connection = nil;
}



#pragma mark init and dealloc

+ (id)keyserverWithDelegate:(id <GPGKeyserverDelegate>)theDelegate {
	return [[[self alloc] initWithDelegate:theDelegate] autorelease];
}

- (id)initWithDelegate:(id <GPGKeyserverDelegate>)theDelegate {
	if (!(self = [super init])) {
		return nil;
	}
	
	self.keyserver = [[GPGOptions sharedOptions] keyserver];
	receivedData = [[NSMutableData alloc] init];
	self.delegate = theDelegate;
	
	return self;
}

- (id)init {	
	return [self initWithDelegate:nil];
}


- (void)dealloc {
	self.keyserver = nil;
	self.connection = nil;
	self.userInfo = nil;
	[receivedData release];
	
	[super dealloc];
}



@end






