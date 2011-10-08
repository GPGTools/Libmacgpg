/*
 Copyright © Roman Zechmeister, 2011
 
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

#import "GPGRemoteUserID.h"
#import "GPGKey.h"
#import "GPGGlobals.h"

@interface GPGRemoteUserID () <GPGUserIDProtocol>

@property (retain) NSString *userID;
@property (retain) NSString *name;
@property (retain) NSString *email;
@property (retain) NSString *comment;
@property (retain) NSDate *creationDate;
@property (retain) NSDate *expirationDate;

@end


@implementation GPGRemoteUserID
@synthesize userID, name, email, comment, creationDate, expirationDate;


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
		
		
		self.userID = [[splitedLine objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		self.creationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:2]];
		self.expirationDate = [NSDate dateWithGPGString:[splitedLine objectAtIndex:3]];
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
	self.userID = nil;
	self.name = nil;
	self.email = nil;
	self.comment = nil;
	self.creationDate = nil;
	self.expirationDate = nil;
	[super dealloc];
}



@end
