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

#import "GPGUserID.h"
#import "GPGKey.h"
#import "GPGController.h"
#import "GPGTask.h"



@implementation GPGUserID

@synthesize index;
@synthesize primaryKey;
@synthesize hashID;
@synthesize name;
@synthesize email;
@synthesize comment;


- (id)children {return nil;}
- (id)length {return nil;}
- (id)algorithm {return nil;}
- (id)keyID {return nil;}
- (id)shortKeyID {return nil;}
- (id)fingerprint {return nil;}

- (NSString *)type {return @"uid";}

- (NSUInteger)hash {
	return [hashID hash];
}
- (BOOL)isEqual:(id)anObject {
	return [hashID isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[hashID retain] autorelease];
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



- (id)initWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing parentKey:(GPGKey *)key {
	[self init];
	primaryKey = key;
	signatures = nil;
	cipherPreferences = nil;
	digestPreferences = nil;
	compressPreferences = nil;
	otherPreferences = nil;
	
	
	[self updateWithListing:listing signatureListing:sigListing];
	return self;	
}
- (void)updateWithListing:(NSArray *)listing signatureListing:(NSArray *)sigListing {
	
	[self updateWithLine:listing];

	
	self.hashID = [listing objectAtIndex:7];
	self.userID = unescapeString([listing objectAtIndex:9]);
	
	
	if (sigListing) {
		signatures = [[GPGKeySignature signaturesWithListing:sigListing] retain];
	} else {
		signatures = nil;
	}
	
	if (cipherPreferences) {
		[cipherPreferences release];
		cipherPreferences = nil;
	}
	if (digestPreferences) {
		[digestPreferences release];
		digestPreferences = nil;
	}
	if (compressPreferences) {
		[compressPreferences release];
		compressPreferences = nil;
	}
	if (otherPreferences) {
		[otherPreferences release];
		otherPreferences = nil;
	}
}

- (NSArray *)signatures {
	//TODO: lock
	if (!signatures) {
		GPGTask *gpgTask = [GPGTask gpgTask];
		[gpgTask addArgument:@"--list-sigs"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:@"--with-fingerprint"];
		[gpgTask addArgument:[primaryKey fingerprint]];
		
		if ([gpgTask start] != 0) {
			@throw gpgTaskException(GPGTaskException, @"List signatures failed!", GPGErrorTaskException, gpgTask);
		}
		
		NSArray *listings, *fingerprints;
		[GPGController colonListing:gpgTask.outText toArray:&listings andFingerprints:&fingerprints];
		
		NSUInteger aIndex = [fingerprints indexOfObject:[primaryKey fingerprint]];
		
		if (aIndex != NSNotFound) {
			[primaryKey updateWithListing:[listings objectAtIndex:aIndex] isSecret:[primaryKey secret] withSigs:YES];
		} else {
			signatures = [[NSArray array] retain];
		}
	}
	return signatures;
}


- (void)updatePreferences:(NSString *)listing {
	NSArray *split = [[[listing componentsSeparatedByString:@":"] objectAtIndex:12] componentsSeparatedByString:@","];
	NSString *prefs = [split objectAtIndex:0];
	
	NSRange range, searchRange;
	NSUInteger stringLength = [prefs length];
	searchRange.location = 0;
	searchRange.length = stringLength;
	
	
	range = [prefs rangeOfString:@"Z" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		compressPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		compressPreferences = [[NSArray alloc] init];
	}
	
	range = [prefs rangeOfString:@"H" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		digestPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		digestPreferences = [[NSArray alloc] init];
	}
	
	range = [prefs rangeOfString:@"S" options:NSLiteralSearch range:searchRange];
	if (range.length > 0) {
		range.length = searchRange.length - range.location;
		searchRange.length = range.location - 1;
		cipherPreferences = [[[prefs substringWithRange:range] componentsSeparatedByString:@" "] retain];
	} else {
		searchRange.length = stringLength;
		cipherPreferences = [[NSArray alloc] init];
	}
	
	//TODO: [mdc] [no-ks-modify]!
}

- (NSArray *)cipherPreferences {
	if (!cipherPreferences) {
		[primaryKey updatePreferences];
	}
	return cipherPreferences;
}
- (NSArray *)digestPreferences {
	if (!digestPreferences) {
		[primaryKey updatePreferences];
	}
	return digestPreferences;
}
- (NSArray *)compressPreferences {
	if (!compressPreferences) {
		[primaryKey updatePreferences];
	}
	return compressPreferences;
}
- (NSArray *)otherPreferences {
	if (!otherPreferences) {
		[primaryKey updatePreferences];
	}
	return otherPreferences;
}



- (void)dealloc {
	[signatures release];
	
	[cipherPreferences release];
	[digestPreferences release];
	[compressPreferences release];
	[otherPreferences release];
	
	self.hashID = nil;
	self.userID = nil;
	
	[super dealloc];
}


@end

