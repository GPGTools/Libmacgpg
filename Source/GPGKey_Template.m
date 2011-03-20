#import "GPGKey_Template.h"


@implementation GPGKey_Template

@synthesize keyID;
@synthesize shortKeyID;
@synthesize algorithm;
@synthesize length;


- (void)updateWithLine:(NSArray *)line {
	[super updateWithLine:line];
	
	length = [[line objectAtIndex:2] intValue];
	algorithm = [[line objectAtIndex:3] intValue];
	self.keyID = [line objectAtIndex:4];
	self.shortKeyID = getShortKeyID(keyID);
	
}

- (void)dealloc {
	self.keyID = nil;
	self.shortKeyID = nil;
	[super dealloc];
}

@end
