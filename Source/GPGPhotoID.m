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

#import "GPGPhotoID.h"
#import "GPGKey.h"

@interface GPGPhotoID ()
@property (nonatomic, retain) NSImage *image;
@property (nonatomic, retain) NSString *hashID;
@end


@implementation GPGPhotoID
@synthesize image, hashID;

- (id)initWithImage:(NSImage *)aImage {
	if (!(self = [super init])) {
		return nil;
	}
	
	self.image = [aImage retain];
	
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
