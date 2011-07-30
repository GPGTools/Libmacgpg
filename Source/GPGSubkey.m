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

#import "GPGSubkey.h"
#import "GPGKey.h"

@interface GPGSubkey ()

@property (assign) GPGKey *primaryKey;
@property (retain) NSString *fingerprint;

@end


@implementation GPGSubkey
@synthesize index, primaryKey, fingerprint;


- (id)children {return nil;}
- (id)name {return nil;}
- (id)email {return nil;}
- (id)comment {return nil;}

- (NSString *)type {return @"sub";}

- (NSUInteger)hash {
	return [fingerprint hash];
}
- (BOOL)isEqual:(id)anObject {
	return [fingerprint isEqualToString:[anObject description]];
}
- (NSString *)description {
	return [[fingerprint retain] autorelease];
}



- (id)initWithListing:(NSArray *)listing fingerprint:(NSString *)aFingerprint parentKey:(GPGKey *)key {
	[self init];
	primaryKey = key;
	self.fingerprint = aFingerprint;
	[self updateWithListing:listing];
	return self;
}
- (void)updateWithListing:(NSArray *)listing {
	[self updateWithLine:listing];
}

- (void)dealloc {
	self.fingerprint = nil;
	
	[super dealloc];
}


@end
