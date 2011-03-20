#import "GPGSuper_Template.h"


@implementation GPGSuper_Template

@synthesize validity;
@synthesize expired;
@synthesize disabled;
@synthesize invalid;
@synthesize revoked;
@synthesize creationDate;
@synthesize expirationDate;


- (void)updateWithLine:(NSArray *)line {
	NSString *letter = [line objectAtIndex:8];
	BOOL invalidVal = NO, revokedVal = NO, expiredVal = NO;
	GPGValidity validityVal = [[self class] validityFromLetter:letter];
	
	if (validityVal != 0 && [letter length] !=0) {
		switch ([letter characterAtIndex:0]) {
			case 'i':
				invalidVal = YES;
				break;
			case 'r':
				revokedVal = YES;
				break;
			case 'e':
				expiredVal = YES;
				break;
		}		
	}
	
	self.validity = validityVal;
	self.invalid = invalidVal;
	self.revoked = revokedVal;
	self.expired = expiredVal;

	
	self.creationDate = [NSDate dateWithGPGString:[line objectAtIndex:5]];
	self.expirationDate = [NSDate dateWithGPGString:[line objectAtIndex:6]];
	if (expirationDate && !expired) {
		expired = [[NSDate date] isGreaterThanOrEqualTo:expirationDate];
	}
	
	self.disabled = ([line count] > 11) ? ([[line objectAtIndex:11] rangeOfString:@"D"].length > 0) : NO;
}

+ (GPGValidity)validityFromLetter:(NSString *)letter {
	if ([letter length] == 0) {
		return 0;
	}
	switch ([letter characterAtIndex:0]) {
		case 'q':
			return 1;
		case 'n':
			return 2;
		case 'm':
			return 3;
		case 'f':
			return 4;
		case 'u':
			return 5;
	}
	return 0;
}


- (NSInteger)status {
	NSInteger statusValue = validity;
	
	if (invalid) {
		statusValue = GPGKeyStatus_Invalid;
	}
	if (revoked) {
		statusValue += GPGKeyStatus_Revoked;
	}
	if (expired) {
		statusValue += GPGKeyStatus_Expired;
	}
	if (disabled) {
		statusValue += GPGKeyStatus_Disabled;
	}
	return statusValue;
}

- (void)dealloc {
	self.creationDate = nil;
	self.expirationDate = nil;
	[super dealloc];
}

@end
