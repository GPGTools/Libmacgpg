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

#import <Libmacgpg/GPGUserID.h>
#import <Libmacgpg/GPGTypesRW.h>

@implementation GPGUserID

@synthesize userIDDescription=_userIDDescription, name=_name, email=_email, comment=_comment, hashID=_hashID, primaryKey=_primaryKey, signatures=_signatures, photo=_photo, validity=_validity;

- (instancetype)init {
	return [self initWithUserIDDescription:nil];
}

- (instancetype)initWithUserIDDescription:(NSString *)userIDDescription {
	if(self = [super init]) {
		_userIDDescription = [userIDDescription copy];
	}
	return self;
}

- (NSUInteger)hash {
	return [self.hashID hash];
}

- (BOOL)isEqual:(id)anObject {
	return [self.hashID isEqualToString:[anObject description]];
}

- (NSString *)description {
	return self.hashID;
}

//- (NSArray *)signatures {
//	@synchronized (self) {
//		if (!signatures) {
//			GPGTask *gpgTask = [GPGTask gpgTask];
//			[gpgTask addArgument:@"--list-sigs"];
//			[gpgTask addArgument:@"--with-fingerprint"];
//			[gpgTask addArgument:@"--with-fingerprint"];
//			[gpgTask addArgument:[primaryKey fingerprint]];
//			
//			if ([gpgTask start] != 0) {
//				@throw [GPGException exceptionWithReason:localizedLibmacgpgString(@"List signatures failed!") gpgTask:gpgTask];
//			}
//			
//			NSArray *listings, *fingerprints;
//			[GPGController colonListing:gpgTask.outText toArray:&listings andFingerprints:&fingerprints];
//			
//			NSUInteger aIndex = [fingerprints indexOfObject:[primaryKey fingerprint]];
//			
//			if (aIndex != NSNotFound) {
//				[primaryKey updateWithListing:[listings objectAtIndex:aIndex] isSecret:[primaryKey secret] withSigs:YES];
//			} else {
//				signatures = [[NSArray array] retain];
//			}
//		}
//	}
//	return [[signatures retain] autorelease];
//}


//- (void)updatePreferences:(NSString *)listing {
//	NSArray *split = [[[listing componentsSeparatedByString:@":"] objectAtIndex:12] componentsSeparatedByString:@","];
//	NSString *prefs = [split objectAtIndex:0];
//	
//	NSRange range, searchRange;
//	NSUInteger stringLength = [prefs length];
//	searchRange.location = 0;
//	searchRange.length = stringLength;
//	
//	
//	range = [prefs rangeOfString:@"Z" options:NSLiteralSearch range:searchRange];
//	if (range.length > 0) {
//		range.length = searchRange.length - range.location;
//		searchRange.length = range.location - 1;
//		compressPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
//	} else {
//		searchRange.length = stringLength;
//		compressPreferences = [[NSArray alloc] init];
//	}
//	
//	range = [prefs rangeOfString:@"H" options:NSLiteralSearch range:searchRange];
//	if (range.length > 0) {
//		range.length = searchRange.length - range.location;
//		searchRange.length = range.location - 1;
//		digestPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
//	} else {
//		searchRange.length = stringLength;
//		digestPreferences = [[NSArray alloc] init];
//	}
//	
//	range = [prefs rangeOfString:@"S" options:NSLiteralSearch range:searchRange];
//	if (range.length > 0) {
//		range.length = searchRange.length - range.location;
//		searchRange.length = range.location - 1;
//		cipherPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
//	} else {
//		searchRange.length = stringLength;
//		cipherPreferences = [[NSArray alloc] init];
//	}
//	
//	//TODO: Support for [mdc] [no-ks-modify]!
//}

- (void)dealloc {
	[_userIDDescription release];
	_userIDDescription = nil;
	[_name release];
	_name = nil;
	[_email release];
	_email = nil;
	[_comment release];
	_comment = nil;
	[_photo release];
	_photo = nil;
	[_hashID release];
	_hashID = nil;
	
	_primaryKey = nil;
	[_signatures release];
	_signatures = nil;
	
	
	[super dealloc];
}


@end

