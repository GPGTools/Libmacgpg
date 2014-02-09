/*
 Copyright © Roman Zechmeister und Lukas Pitschl (@lukele), 2014
 
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

#import "GPGUserIDSignature.h"
#import "GPGTypesRW.h"

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

- (NSImage *)image {
	return self.primaryKey.image;
}

- (NSString *)shortKeyID {
	return [self.keyID shortKeyID];
}

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
