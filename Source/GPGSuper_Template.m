/*
 Copyright © Roman Zechmeister, 2013
 
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

#import "GPGSuper_Template.h"

@interface GPGSuper_Template ()

@property GPGValidity validity;
@property BOOL expired ,disabled, invalid, revoked;
@property (retain) NSDate *creationDate, *expirationDate;

@end


@implementation GPGSuper_Template
@synthesize validity, expired, disabled, invalid, revoked, creationDate, expirationDate;


- (void)updateWithLine:(NSArray *)line {
	NSString *letter = [line objectAtIndex:1];
	BOOL isInvalid = NO, isRevoked = NO, isExpired = NO;
	GPGValidity validityVal = [[self class] validityFromLetter:letter];
	
	if ([letter length] > 0) {
		switch ([letter characterAtIndex:0]) {
			case 'i':
				isInvalid = YES;
				break;
			case 'r':
				isRevoked = YES;
				break;
			case 'e':
				isExpired = YES;
				break;
		}		
	}
	
	self.validity = validityVal;
	self.invalid = isInvalid;
	self.revoked = isRevoked;
	self.expired = isExpired;

	
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
