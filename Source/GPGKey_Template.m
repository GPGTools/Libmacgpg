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

#import "GPGKey_Template.h"


@interface GPGKey_Template ()

@property (retain) NSString *keyID;
@property (retain) NSString *shortKeyID;
@property (retain) NSString *capabilities;
@property GPGPublicKeyAlgorithm algorithm;
@property unsigned int length;
@property BOOL canEncrypt, canSign, canCertify, canAuthenticate, canAnyEncrypt, canAnySign, canAnyCertify, canAnyAuthenticate, disabled;

@end


@implementation GPGKey_Template
@synthesize keyID, shortKeyID, algorithm, length, canEncrypt, canSign, canCertify, canAuthenticate, canAnyEncrypt, canAnySign, canAnyCertify, canAnyAuthenticate, capabilities;
@dynamic disabled;


- (void)updateWithLine:(NSArray *)line {
	[super updateWithLine:line];
	
	self.length = [[line objectAtIndex:2] intValue];
	self.algorithm = [[line objectAtIndex:3] intValue];
	self.keyID = [line objectAtIndex:4];
	self.shortKeyID = [keyID shortKeyID];
	
	
	self.capabilities = [line objectAtIndex:11];
	
	const char *char_capabilities = [capabilities cStringUsingEncoding:NSASCIIStringEncoding];
	BOOL canSignVal = 0, canEncryptVal = 0, canCertifyVal = 0, canAuthenticateVal = 0, canAnySignVal = 0, canAnyEncryptVal = 0, canAnyCertifyVal = 0, canAnyAuthenticateVal = 0, disabledVal = 0;
	
	for (; *char_capabilities; char_capabilities++) {
		switch (*char_capabilities) {
			case 'd':
			case 'D':
				disabledVal = 1;
				break;
			case 'e':
				canEncryptVal = 1;
				break;
			case 's':
				canSignVal = 1;
				break;
			case 'c':
				canCertifyVal = 1;
				break;
			case 'a':
				canAuthenticateVal = 1;
				break;
			case 'E':
				canAnyEncryptVal = 1;
				break;
			case 'S':
				canAnySignVal = 1;
				break;
			case 'C':
				canAnyCertifyVal = 1;
				break;
			case 'A':
				canAnyAuthenticateVal = 1;
				break;
		}
	}
	
	
	self.canEncrypt = canEncryptVal;
	self.canSign = canSignVal;
	self.canCertify = canCertifyVal;
	self.canAuthenticate = canAuthenticateVal;
	self.canAnyEncrypt = canAnyEncryptVal;
	self.canAnySign = canAnySignVal;
	self.canAnyCertify = canAnyCertifyVal;
	self.canAnyAuthenticate = canAnyAuthenticateVal;
	self.disabled = disabledVal;
	
}




- (void)dealloc {
	self.keyID = nil;
	self.shortKeyID = nil;
	[super dealloc];
}

@end
