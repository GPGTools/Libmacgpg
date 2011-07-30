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

#import "GPGPhotoID.h"
#import "GPGKey.h"

@interface GPGPhotoID ()

@property (retain) NSImage *image;
@property (retain) NSString *hashID;
@property NSInteger status;

@end


@implementation GPGPhotoID
@synthesize image, hashID, status;

- (id)initWithImage:(NSImage *)aImage hashID:(NSString *)aHashID status:(NSInteger)aStatus {
	[self init];
	
	self.image = [aImage retain];
	self.hashID = [aHashID retain];
	self.status = aStatus;
	
	return self;
}

- (void)dealloc {
	self.image = nil;
	self.hashID = nil;
	
	[super dealloc];
}

- (NSUInteger)hash {
	return [hashID hash];
}
- (BOOL)isEqual:(id)anObject {
	return [hashID isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[hashID retain] autorelease];
}


@end
