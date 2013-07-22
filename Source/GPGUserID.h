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

 Additions by: Lukas Pitschl (@lukele) (c) 2013
*/

#import <Libmacgpg/GPGGlobals.h>

@protocol GPGUserIDProtocol <NSObject>

@property (nonatomic, readonly) NSString *userIDDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;
@property (nonatomic, readonly) NSImage *photo;

@end

@class GPGKey;

@interface GPGUserID : NSObject <GPGUserIDProtocol> {
	NSString *_userIDDescription;
	NSString *_name;
	NSString *_email;
	NSString *_comment;
	NSString *_hashID;
	NSImage *_photo;
	GPGValidity _validity;
	
	GPGKey *_primaryKey;
	NSArray *_signatures;
	
	NSArray *_cipherPreferences;
	NSArray *_digestPreferences;
	NSArray *_compressPreferences;
	
}

- (instancetype)init;
- (instancetype)initWithUserIDDescription:(NSString *)userIDDescription;

@property (nonatomic, readonly) NSString *userIDDescription;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSString *comment;
@property (nonatomic, readonly) NSString *hashID;
@property (nonatomic, readonly) NSImage *photo;
@property (nonatomic, readonly) GPGValidity validity;

@property (nonatomic, readonly) NSArray *signatures;
@property (nonatomic, readonly) GPGKey *primaryKey;

@property (nonatomic, readonly) NSArray *cipherPreferences;
@property (nonatomic, readonly) NSArray *digestPreferences;
@property (nonatomic, readonly) NSArray *compressPreferences;

@end

