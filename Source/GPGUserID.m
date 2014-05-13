/*
 Copyright © Roman Zechmeister, 2014
 
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

#import "GPGUserID.h"
#import "GPGTypesRW.h"


@implementation GPGUserID
@synthesize userIDDescription, name, email, comment, hashID, primaryKey, signatures, image, expirationDate, creationDate, validity;

- (instancetype)init {
	return [self initWithUserIDDescription:nil];
}

- (instancetype)initWithUserIDDescription:(NSString *)value {
	if(self = [super init]) {
		self.userIDDescription = value;
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


@end

