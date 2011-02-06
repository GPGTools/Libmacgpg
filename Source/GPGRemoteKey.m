#import "GPGRemoteKey.h"
#import "GPGRemoteUserID.h"

@implementation GPGRemoteKey

@synthesize keyID;
@synthesize algorithm;
@synthesize length;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize expired;
@synthesize revoked;
@synthesize userIDs;



+ (NSArray *)keysWithListing:(NSString *)listing {
	NSArray *lines = [listing componentsSeparatedByString:@"\n"];
	NSMutableArray *keys = [NSMutableArray array];
	NSRange range;
	range.location = NSNotFound;
	NSUInteger i = 0, count = [lines count];
	
	
	for (; i < count; i++) {
		if ([[lines objectAtIndex:i] hasPrefix:@"pub:"]) {
			if (range.location != NSNotFound) {
				range.length = i - range.location;
				[keys addObject:[self keyWithListing:[lines subarrayWithRange:range]]];
			}
			range.location = i;
		}
	}
	if (range.location != NSNotFound) {
		range.length = i - range.location;
		[keys addObject:[self keyWithListing:[lines subarrayWithRange:range]]];
	}
	
	return keys;
}

+ (id)keyWithListing:(NSArray *)listing {
	return [[[self alloc] initWithListing:listing] autorelease];
}

- (id)initWithListing:(NSArray *)listing {
	if ((self = [super init]) == nil) {
		return nil;
	}
	
	NSArray *splitedLine = [[listing objectAtIndex:0] componentsSeparatedByString:@":"];
	
	keyID = [[splitedLine objectAtIndex:1] retain];
	algorithm = [[splitedLine objectAtIndex:2] intValue];
	length = [[splitedLine objectAtIndex:3] integerValue];
	
	creationDate = [[NSDate dateWithGPGString:[splitedLine objectAtIndex:4]] retain];
	expirationDate = [[NSDate dateWithGPGString:[splitedLine objectAtIndex:5]] retain];
	if (expirationDate && !expired) {
		expired = [[NSDate date] isGreaterThanOrEqualTo:expirationDate];
	}

	if ([[splitedLine objectAtIndex:6] length] > 0) {
		if ([[splitedLine objectAtIndex:6] isEqualToString:@"r"]) {
			revoked = YES;
		} else {
			NSLog(@"Uknown flag: %@", [listing objectAtIndex:0]);
		}
	}
	
	NSUInteger i = 1, c = [listing count];
	NSMutableArray *theUserIDs = [[NSMutableArray alloc] initWithCapacity:c - 1];
	for (; i < c; i++) {
		GPGRemoteUserID *tempUserID = [GPGRemoteUserID userIDWithListing:[listing objectAtIndex:i]];
		if (tempUserID) {
			[theUserIDs addObject:tempUserID]; 
		}
	}
	userIDs = theUserIDs;
	
	
	return self;	
}

- (void)dealloc {
	[keyID release];
	[creationDate release];
	[expirationDate release];
	[userIDs release];
	[super dealloc];
}

- (NSUInteger)hash {
	return [keyID hash];
}
- (BOOL)isEqual:(id)anObject {
	return [keyID isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[keyID retain] autorelease];
}


@end
