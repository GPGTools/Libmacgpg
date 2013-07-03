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

#import "GPGKeySignature.h"
#import "GPGKey.h"

@interface GPGKeySignature () <GPGUserIDProtocol>

@property (nonatomic) BOOL local;
@property (nonatomic) BOOL revocationSignature;
@property (nonatomic) int signatureClass;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, retain) NSString *keyID;
@property (nonatomic, retain) NSString *shortKeyID;
@property (nonatomic, retain) NSString *description;
@property (nonatomic) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSDate *expirationDate;

@end

@implementation GPGKeySignature
@synthesize type, revocationSignature, local, signatureClass, userID, name, email, comment, algorithm, creationDate, expirationDate, keyID, shortKeyID, description;


+ (NSArray *)signaturesWithListing:(NSArray *)listing {
	NSUInteger i, count = listing.count;
	NSMutableArray *signatures = [NSMutableArray arrayWithCapacity:count];
	NSRange range;
	range.location = NSNotFound;
	for (i = 0; i < count; i++) {
		NSString *line = [listing objectAtIndex:i];
		if ([line hasPrefix:@"sig:"] || [line hasPrefix:@"rev:"]) {
			if (range.location != NSNotFound) {
				range.length = i - range.location;
				[signatures addObject:[self signatureWithListing:[listing subarrayWithRange:range]]];
			}
			range.location = i;
		}
	}
	if (range.location != NSNotFound) {
		range.length = i - range.location;
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
			self.revocationSignature = [recType isEqualToString:@"rev"];
			
			self.algorithm = [[splitedLine objectAtIndex:3] intValue];
			self.keyID = [splitedLine objectAtIndex:4];
			self.shortKeyID = [keyID shortKeyID];
			
			self.creationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:5]];
			self.expirationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:6]];
			self.userID = [[splitedLine objectAtIndex:9] unescapedString];
			
			tempItem = [splitedLine objectAtIndex:10];
			self.signatureClass = hexToByte([tempItem UTF8String]);
			self.local = [tempItem hasSuffix:@"l"];
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
					self.description = [[splitedLine objectAtIndex:1] unescapedString];
					break;
			}
		}
		
	}
		
		
		
	return self;
}


- (void)setUserID:(NSString *)value {
	if (value != userID) {
		[userID release];
		userID = [value retain];
		
		[GPGKey setInfosWithUserID:userID toObject:self];
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