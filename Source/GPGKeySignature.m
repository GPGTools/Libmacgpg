/*
 Copyright © Roman Zechmeister, 2010
 
 Dieses Programm ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import "GPGKeySignature.h"
#import "GPGKey.h"


@implementation GPGKeySignature

@synthesize type;
@synthesize revocationSignature;
@synthesize local;
@synthesize signatureClass;
@synthesize userID;
@synthesize name;
@synthesize email;
@synthesize comment;
@synthesize algorithm;
@synthesize creationDate;
@synthesize expirationDate;
@synthesize keyID;
@synthesize shortKeyID;
@synthesize description;


+ (NSArray *)signaturesWithListing:(NSArray *)listing {
	NSUInteger i, count = listing.count;
	NSMutableArray *signatures = [NSMutableArray arrayWithCapacity:count];
	NSRange range;
	range.location = NSNotFound;
	for (i = 0; i < count; i++) {
		NSString *line = [listing objectAtIndex:i];
		if ([line hasPrefix:@"sig:"] || [line hasPrefix:@"rev:"]) {
			if (range.location != NSNotFound) {
				range.length = i - range.location - 1;
				[signatures addObject:[self signatureWithListing:[listing subarrayWithRange:range]]];
			}
			range.location = i;
		}
	}
	if (range.location != NSNotFound) {
		range.length = i - range.location - 1;
		[signatures addObject:[self signatureWithListing:[listing subarrayWithRange:range]]];
	}
	return signatures;
}



+ (id)signatureWithListing:(NSArray *)listing {
	return [[[GPGKeySignature alloc] initWithListing:listing] autorelease];
}
- (id)initWithListing:(NSArray *)listing {
	if (!(self = [super init])) {
		return nil;
	}
	
	for (NSString *line in listing) {
		NSArray *splitedLine = [line componentsSeparatedByString:@":"];
		NSString *tempItem, *recType;
		
		recType = [splitedLine objectAtIndex:0];
		
		if ([recType isEqualToString:@"sig"] || [recType isEqualToString:@"rev"]) {
			revocationSignature = [recType isEqualToString:@"rev"];
			
			algorithm = [[splitedLine objectAtIndex:3] intValue];
			self.keyID = [splitedLine objectAtIndex:4];
			self.shortKeyID = getShortKeyID(keyID);
			
			self.creationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:5]];
			self.expirationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:6]];
			self.userID = unescapeString([splitedLine objectAtIndex:9]);
			
			tempItem = [splitedLine objectAtIndex:10];
			signatureClass = hexToByte([tempItem UTF8String]);
			local = [tempItem hasSuffix:@"l"];
			NSMutableString *sigType = [NSMutableString stringWithString:revocationSignature ? @"rev" : @"sig"];
			if (signatureClass & 3) {
				[sigType appendFormat:@" %i", signatureClass & 3];
			}
			if (local) {
				[sigType appendString:@" L"];
			}
			self.type = sigType;			
		} else if ([recType isEqualToString:@"spk"]) {
			switch ([[splitedLine objectAtIndex:1] integerValue]) {
				case 29:
					self.description = unescapeString([splitedLine objectAtIndex:1]);
					break;
			}
		}
		
	}
		
		
		
	return self;
}


- (NSString *)userID {
	return [[userID retain] autorelease];
}
- (void)setUserID:(NSString *)value {
	if (value != userID) {
		[userID release];
		userID = [value retain];
		
		NSString *tName, *tEmail, *tComment;
		[GPGKey splitUserID:value intoName:&tName email:&tEmail comment:&tComment];
		
		self.name = tName;
		self.email = tEmail;
		self.comment = tComment;
	}
}

- (void)dealloc {
	self.type = nil;
	self.userID = nil;;
	
	self.keyID = nil;
	self.shortKeyID = nil;
	
	self.creationDate = nil;
	self.expirationDate = nil;
	
	self.description = nil;
	
	[super dealloc];
}

@end