#import "GPGRemoteUserID.h"
#import "GPGKey.h"
#import "GPGGlobals.h"

@implementation GPGRemoteUserID

@synthesize userID;
@synthesize name;
@synthesize email;
@synthesize comment;
@synthesize creationDate;
@synthesize expirationDate;


+ (id)userIDWithListing:(NSString *)listing {
	return [[[self alloc] initWithListing:listing] autorelease];
}

- (id)initWithListing:(NSString *)listing {
	if (self = [super init]) {
		NSArray *splitedLine = [listing componentsSeparatedByString:@":"];
		
		if ([splitedLine count] < 4) {
			[self release];
			return nil;
		}
		
		
		userID = [unescapeString([splitedLine objectAtIndex:1]) retain];
		[GPGKey splitUserID:userID intoName:&name email:&email comment:&comment];
		[name retain];
		[email retain];
		[comment retain];
		
		creationDate = [[NSDate dateWithGPGString:[splitedLine objectAtIndex:2]] retain];
		expirationDate = [[NSDate dateWithGPGString:[splitedLine objectAtIndex:3]] retain];
	}
	return self;	
}

- (void)dealloc {
	[name release];
	[email release];
	[comment release];
	[creationDate release];
	[expirationDate release];
	[super dealloc];
}



@end
