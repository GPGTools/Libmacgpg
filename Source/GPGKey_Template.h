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

#import <Libmacgpg/GPGGlobals.h>
#import <Libmacgpg/GPGSuper_Template.h>


@interface GPGKey_Template : GPGSuper_Template {
	NSString *keyID;
	NSString *shortKeyID;
	NSString *capabilities;
	
	GPGPublicKeyAlgorithm algorithm;
	unsigned int length;
	
	BOOL canEncrypt, canSign, canCertify, canAuthenticate; //Capabilities of the key.
	BOOL canAnyEncrypt, canAnySign, canAnyCertify, canAnyAuthenticate; //Capabilities of the key and the subkeys.
}

@property (nonatomic, readonly, retain) NSString *keyID;
@property (nonatomic, readonly, retain) NSString *shortKeyID;
@property (nonatomic, readonly, retain) NSString *capabilities;
@property (nonatomic, readonly) GPGPublicKeyAlgorithm algorithm;
@property (nonatomic, readonly) unsigned int length;
@property (nonatomic, readonly) BOOL canEncrypt, canSign, canCertify, canAuthenticate, canAnyEncrypt, canAnySign, canAnyCertify, canAnyAuthenticate;


@end
