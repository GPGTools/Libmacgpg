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

 Additions by: Lukas Pitschl (@lukele) (c) 2013
*/

#import <Libmacgpg/GPGUserIDSignature.h>
#import <Libmacgpg/GPGTypesRW.h>

@implementation GPGUserIDSignature

@synthesize keyID=_keyID, algorithm=_algorithm, creationDate=_creationDate, expirationDate=_expirationDate, reason=_reason, signatureClass=_signatureClass, revocation=_revocation, local=_local, primaryKey=_primaryKey;

- (instancetype)init {
	return [self initWithKeyID:nil];
}

- (instancetype)initWithKeyID:(NSString *)keyID {
	if(self = [super init]) {
		_keyID = [keyID copy];
	}
	return self;
}

- (NSString *)userIDDescription {
	return self.primaryKey.userIDDescription;
}

- (NSString *)name {
	return self.primaryKey.name;
}

- (NSString *)email {
	return self.primaryKey.email;
}

- (NSString *)comment {
	return self.primaryKey.comment;
}

- (NSImage *)photo {
	return self.primaryKey.photo;
}

- (NSString *)shortKeyID {
	return [self.keyID shortKeyID];
}

//+ (NSArray *)signaturesWithListing:(NSArray *)listing {
//	NSUInteger i, count = listing.count;
//	NSMutableArray *signatures = [NSMutableArray arrayWithCapacity:count];
//	NSRange range;
//	range.location = NSNotFound;
//	for (i = 0; i < count; i++) {
//		NSString *line = [listing objectAtIndex:i];
//		if ([line hasPrefix:@"sig:"] || [line hasPrefix:@"rev:"]) {
//			if (range.location != NSNotFound) {
//				range.length = i - range.location;
//				[signatures addObject:[self signatureWithListing:[listing subarrayWithRange:range]]];
//			}
//			range.location = i;
//		}
//	}
//	if (range.location != NSNotFound) {
//		range.length = i - range.location;
//		[signatures addObject:[self signatureWithListing:[listing subarrayWithRange:range]]];
//	}
//	return signatures;
//}



//+ (id)signatureWithListing:(NSArray *)listing {
//	return [[[GPGKeySignature alloc] initWithListing:listing] autorelease];
//}
//- (id)initWithListing:(NSArray *)listing {
//	if (!(self = [super init])) {
//		return nil;
//	}
//	
//	for (NSString *line in listing) {
//		NSArray *splitedLine = [line componentsSeparatedByString:@":"];
//		NSString *tempItem, *recType;
//		
//		recType = [splitedLine objectAtIndex:0];
//		
//		if ([recType isEqualToString:@"sig"] || [recType isEqualToString:@"rev"]) {
//			self.revocationSignature = [recType isEqualToString:@"rev"];
//			
//			self.algorithm = [[splitedLine objectAtIndex:3] intValue];
//			self.keyID = [splitedLine objectAtIndex:4];
//			self.shortKeyID = [keyID shortKeyID];
//			
//			self.creationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:5]];
//			self.expirationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:6]];
//			self.userID = [[splitedLine objectAtIndex:9] unescapedString];
//			
//			tempItem = [splitedLine objectAtIndex:10];
//			self.signatureClass = hexToByte([tempItem UTF8String]);
//			self.local = [tempItem hasSuffix:@"l"];
//			NSMutableString *sigType = [NSMutableString stringWithString:revocationSignature ? @"rev" : @"sig"];
//			if (signatureClass & 3) {
//				[sigType appendFormat:@" %i", signatureClass & 3];
//			}
//			if (local) {
//				[sigType appendString:@" L"];
//			}
//			self.type = sigType;			
//		} else if ([recType isEqualToString:@"spk"]) {
//			switch ([[splitedLine objectAtIndex:1] integerValue]) {
//				case 29:
//					self.description = [[splitedLine objectAtIndex:1] unescapedString];
//					break;
//			}
//		}
//		
//	}
//		
//		
//		
//	return self;
//}

//
//- (void)setUserID:(NSString *)value {
//	if (value != userID) {
//		[userID release];
//		userID = [value retain];
//		
//		[GPGKey setInfosWithUserID:userID toObject:self];
//	}
//}

- (void)dealloc {
	[_keyID release];
	_keyID = nil;
	_algorithm = 0;
	[_creationDate release];
	_creationDate = nil;
	[_expirationDate release];
	_expirationDate = nil;
	[_reason release];
	_reason = nil;
	_signatureClass = 0;
	_revocation = NO;
	_local = NO;
	
	_primaryKey = nil;
	
	
	[super dealloc];
}

@end
